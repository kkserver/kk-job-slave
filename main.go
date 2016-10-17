package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/kkserver/kk-job/job"
	"github.com/kkserver/kk-lib/kk"
	"log"
	"os"
	"os/exec"
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

	b, err := json.Marshal(data)

	if err != nil {

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
	}

	return nil
}

func createTextFile(text string, path string) error {

	os.Remove(path)

	fd, err := os.Create(path)

	if err != nil {
		return err
	}

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

func createENVFile(options map[string]interface{}, path string) error {

	os.Remove(path)

	fd, err := os.Create(path)

	if err != nil {
		return err
	}

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

	return nil
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

						log.Println(err)

						createTextFile(err.Error(), name+"fail")

						var fail = job.JobVersionFailTaskResult{}

						request(sendRequest, baseURL+"job/slave/fail", time.Second, map[string]interface{}{
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
							json.Unmarshal([]byte(result.Job.Options), &options)
						}

						err = createENVFile(options, name+"options.sh")

						if err != nil {
							fail(err)
							return
						}

						cmd := exec.Command("/bin/sh", "-c", workdir+"/run.sh")

						cmd.Dir = name

						stdout, err := cmd.StdoutPipe()

						if err != nil {
							fail(err)
							return
						}

						defer stdout.Close()

						stderr, err := cmd.StderrPipe()

						if err != nil {
							fail(err)
							return
						}

						err = cmd.Start()

						if err != nil {
							fail(err)
							return
						}

						defer stderr.Close()

						go func() {

							rd := bufio.NewReader(stdout)

							for true {

								v, err := rd.ReadString('\n')

								if err != nil {
									break
								}

								var r = job.JobVersionLogTaskResult{}

								request(sendRequest, baseURL+"job/slave/log", time.Second, map[string]interface{}{
									"jobId":   fmt.Sprintf("%d", result.Version.JobId),
									"version": fmt.Sprintf("%d", result.Version.Version),
									"log":     fmt.Sprintf("[INFO] %s", v)}, &r)

							}

						}()

						go func() {

							rd := bufio.NewReader(stderr)

							for true {

								v, err := rd.ReadString('\n')

								if err != nil {
									break
								}

								var r = job.JobVersionLogTaskResult{}

								request(sendRequest, baseURL+"job/slave/log", time.Second, map[string]interface{}{
									"jobId":   fmt.Sprintf("%d", result.Version.JobId),
									"version": fmt.Sprintf("%d", result.Version.Version),
									"log":     fmt.Sprintf("[FAIL] %s", v)}, &r)

							}

						}()

						err = cmd.Wait()

						if err != nil {
							fail(err)
							return
						}

						var r = job.JobVersionOKTaskResult{}

						request(sendRequest, baseURL+"job/slave/ok", time.Second, map[string]interface{}{
							"jobId":   fmt.Sprintf("%d", result.Version.JobId),
							"version": fmt.Sprintf("%d", result.Version.Version)}, &r)

						exit()

					})

					return
				}

				var fail = job.JobVersionFailTaskResult{}

				request(sendRequest, baseURL+"job/slave/fail", time.Second, map[string]interface{}{
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

	kk.DispatchMain()

	for _, v := range process {
		v.Break()
	}

}
