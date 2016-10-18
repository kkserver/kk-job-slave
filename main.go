package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/kkserver/kk-job/job"
	"github.com/kkserver/kk-lib/kk"
	"log"
	"os"
	"os/exec"
	"runtime/debug"
	"time"
)

func help() {
	fmt.Println("kk-job-slave <name> <127.0.0.1:8700> <kk.job.> <token> <workdir>")
}

func request(sendRequest func(message *kk.Message, timeout time.Duration) *kk.Message, to string, timeout time.Duration, data interface{}, result interface{}) error {

	log.Printf("[REQUEST] %s ...\n", to)

	var b, _ = json.Marshal(data)
	var v = kk.Message{"REQUEST", "", to, "text/json", b}
	var r = sendRequest(&v, timeout)

	log.Printf("[REQUEST] %s %s\n", to, r.String())

	if r == nil {
		return errors.New(fmt.Sprintf("TO: %s fail", to))
	}

	if r.Method != "REQUEST" {
		return errors.New(fmt.Sprintf("TO: %s %s", to, r.String()))
	}

	if r.Type == "text/json" || r.Type == "application/json" {
		return json.Unmarshal(r.Content, result)
	}

	return nil
}

func createJSONFile(data interface{}, path string) error {

	os.Remove(path)

	fd, err := os.Create(path)

	if err != nil {
		return err
	}

	defer fd.Close()

	os.Chmod(path, 0777)

	b, err := json.Marshal(data)

	if err == nil {

		var n = 0

		for n != len(b) {

			n, err := fd.Write(b)

			if err != nil {
				log.Println("[FAIL] " + err.Error())
				return err
			}

			if n != len(b) {
				b = b[n:]
			} else {
				break
			}
		}
	} else {
		log.Println("[FAIL] " + err.Error())
	}

	return nil
}

func createTextFile(text string, path string) error {

	os.Remove(path)

	fd, err := os.Create(path)

	if err != nil {
		return err
	}

	os.Chmod(path, 0777)

	defer fd.Close()

	b := []byte(text)

	var n = 0

	for n != len(b) {

		n, err := fd.Write(b)

		if err != nil {
			return err
		}

		if n != len(b) {
			b = b[n:]
		} else {
			break
		}
	}

	return nil
}

func createShellFile(options map[string]interface{}, path string, cmd string) error {

	os.Remove(path)

	fd, err := os.Create(path)

	if err != nil {
		return err
	}

	os.Chmod(path, 0777)

	defer fd.Close()

	fd.WriteString("#/bin/sh\n\n")

	for key, value := range options {
		var option, ok = value.(map[string]interface{})
		if ok {
			v, ok := option["value"]
			if ok {
				b, _ := json.Marshal(v)
				fmt.Fprintf(fd, "export %s=%s\n", key, string(b))
			}

		}
	}

	fd.WriteString("\n\n")

	fd.WriteString(cmd)

	fd.WriteString("\n")

	return nil
}

func writeLogFile(tag string, log string, path string) error {

	fd, err := os.OpenFile(path, os.O_APPEND, os.ModePerm)

	if err != nil {

		fd, err = os.Create(path)

		if err != nil {
			return err
		}

		os.Chmod(path, 0777)

	}

	defer fd.Close()

	fd.WriteString(fmt.Sprintf("[%s][%s] %s", tag, time.Now().String(), log))

	return nil
}

type LogWriter struct {
	fd          *os.File
	tag         string
	token       string
	jobId       int64
	version     int
	baseURL     string
	sendRequest func(message *kk.Message, timeout time.Duration) *kk.Message
	line        *bytes.Buffer
}

func NewLogWriter(path string, tag string, token string, jobId int64, version int, baseURL string, sendRequest func(message *kk.Message, timeout time.Duration) *kk.Message) (log *LogWriter, err error) {
	var v = LogWriter{}
	var e error = nil

	v.fd, e = os.OpenFile(path, os.O_APPEND, 0)

	if e != nil {

		v.fd, e = os.Create(path)

		if e != nil {
			return nil, e
		}

		os.Chmod(path, 0777)

	}

	v.tag = tag
	v.token = token
	v.jobId = jobId
	v.version = version
	v.baseURL = baseURL
	v.sendRequest = sendRequest
	v.line = bytes.NewBuffer(nil)

	return &v, nil
}

func (L *LogWriter) Close() error {
	return L.fd.Close()
}

func (L *LogWriter) Write(p []byte) (n int, err error) {

	for _, c := range p {
		if c == '\n' {
			var r = job.JobVersionLogTaskResult{}
			request(L.sendRequest, L.baseURL+"job/slave/log", time.Second, map[string]interface{}{
				"token":   L.token,
				"jobId":   fmt.Sprintf("%d", L.jobId),
				"version": fmt.Sprintf("%d", L.version),
				"tag":     L.tag,
				"log":     L.line.String()}, &r)
			L.line.Reset()

		} else {
			L.line.WriteByte(c)
		}
	}

	return L.fd.Write(p)
}

func main() {

	log.SetFlags(log.Llongfile | log.LstdFlags)

	var args = os.Args
	var name string = ""
	var address string = ""
	var baseURL string = ""
	var token string = ""
	var workdir string = ""

	if len(args) > 4 {
		name = args[1]
		address = args[2]
		baseURL = args[3]
		token = args[4]
		workdir = args[5]
	} else {
		help()
		return
	}

	var sendRequest, _ = kk.TCPClientRequestConnect(name, address, map[string]interface{}{"exclusive": true})

	var process map[string]*kk.Dispatch = map[string]*kk.Dispatch{}
	var online func() = nil

	online = func() {

		var result = job.JobSlaveOnlineTaskResult{}

		var err = request(sendRequest, baseURL+"job/slave/online", time.Second, map[string]interface{}{"token": token}, &result)

		if err != nil {
			log.Println(err)
		} else if result.Errno == 0 {
			createJSONFile(result.Slave, workdir+"/job/slave.json")
		} else {
			log.Println(result.Errmsg)
		}

		kk.GetDispatchMain().AsyncDelay(func() {

			go online()

		}, time.Second*6)

	}

	var jobProcess func() = nil

	jobProcess = func() {

		var result = job.JobSlaveProcessTaskResult{}

		var err = request(sendRequest, baseURL+"job/slave/process", time.Second, map[string]interface{}{"token": token}, &result)

		if err != nil {

			log.Println(err)

			kk.GetDispatchMain().AsyncDelay(func() {
				go jobProcess()
			}, time.Second*6)

		} else if result.Errno == 0 {

			if result.Version != nil {

				var name = fmt.Sprintf("%s/job/%d_%d/", workdir, result.Version.JobId, result.Version.Version)

				_, err := os.Stat(name)

				if err != nil {

					var p = kk.NewDispatch()

					process[name] = p

					var exit = func() {

						kk.GetDispatchMain().Async(func() {

							p.Break()

							delete(process, name)

							go jobProcess()

						})

					}

					var fail = func(err error) {

						log.Println("[FAIL] " + err.Error())

						debug.PrintStack()

						createTextFile(err.Error(), name+"fail")

						var fail = job.JobVersionFailTaskResult{}

						request(sendRequest, baseURL+"job/slave/fail", time.Second, map[string]interface{}{
							"token":      token,
							"jobId":      fmt.Sprintf("%d", result.Version.JobId),
							"version":    fmt.Sprintf("%d", result.Version.Version),
							"statusText": err.Error()}, &fail)

						exit()

					}

					p.Async(func() {

						err := os.Mkdir(name, 0777)

						if err != nil {
							fail(err)
							return
						}

						err = createJSONFile(result.Job, name+"job.json")

						if err != nil {
							fail(err)
							return
						}

						err = createJSONFile(result.Slave, name+"slave.json")

						if err != nil {
							fail(err)
							return
						}

						err = createJSONFile(result.Version, name+"version.json")

						if err != nil {
							fail(err)
							return
						}

						var options = map[string]interface{}{}

						if result.Job.Options != "" {
							json.Unmarshal([]byte(result.Job.Options), &options)
						}

						if result.Version.Options != "" {

							var opts = map[string]interface{}{}

							json.Unmarshal([]byte(result.Job.Options), &opts)

							for key, value := range opts {
								opt, ok := options[key]
								if ok {
									m, ok := opt.(map[string]interface{})
									if ok {
										m[key] = value
									}
								}
							}
						}

						err = createShellFile(options, name+"run.sh", workdir+"/run.sh")

						if err != nil {
							fail(err)
							return
						}

						cmd := exec.Command("/bin/sh", "-c", name+"run.sh")

						cmd.Dir = name

						stderr, err := NewLogWriter(name+"fail.log", "FAIL", token, result.Version.JobId, result.Version.Version, baseURL, sendRequest)

						cmd.Stderr = stderr

						defer stderr.Close()

						stdout, err := NewLogWriter(name+"info.log", "INFO", token, result.Version.JobId, result.Version.Version, baseURL, sendRequest)

						cmd.Stdout = stdout

						defer stdout.Close()

						err = cmd.Start()

						if err != nil {
							fail(err)
							return
						}

						err = cmd.Wait()

						if err != nil {
							log.Println(workdir + "/run.sh")
							fail(err)
							return
						}

						var r = job.JobVersionOKTaskResult{}

						request(sendRequest, baseURL+"job/slave/ok", time.Second, map[string]interface{}{
							"token":   token,
							"jobId":   fmt.Sprintf("%d", result.Version.JobId),
							"version": fmt.Sprintf("%d", result.Version.Version)}, &r)

						writeLogFile("INFO", "EXIT", name+"info.log")

						exit()
					})

					return
				}

				var fail = job.JobVersionFailTaskResult{}

				request(sendRequest, baseURL+"job/slave/fail", time.Second, map[string]interface{}{
					"token":   token,
					"jobId":   fmt.Sprintf("%d", result.Version.JobId),
					"version": fmt.Sprintf("%d", result.Version.Version)}, &fail)

				log.Printf("[FAIL] jobId:%d version:%d %s\n", result.Version.JobId, result.Version.Version)

				kk.GetDispatchMain().AsyncDelay(func() {
					go jobProcess()
				}, time.Second*6)

			} else {
				kk.GetDispatchMain().AsyncDelay(func() {
					go jobProcess()
				}, time.Second*6)
			}

		} else {

			log.Println(result.Errmsg)

			kk.GetDispatchMain().AsyncDelay(func() {
				go jobProcess()
			}, time.Second*6)
		}
	}

	kk.GetDispatchMain().AsyncDelay(func() {

		go func() {

			var result = job.JobSlaveLoginTask{}

			var err = request(sendRequest, baseURL+"job/slave/login", time.Second, map[string]interface{}{"token": token}, &result)

			if err != nil {

				log.Println(err)

				kk.GetDispatchMain().Break()

				return
			}

			go online()

			go jobProcess()

		}()

	}, time.Second)

	kk.GetDispatchMain().AsyncDelay(func() {
		go jobProcess()
	}, time.Second)

	kk.DispatchMain()

	for _, v := range process {
		v.Break()
	}

}
