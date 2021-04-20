package listener

import (
	"bytes"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
)

type Listener struct {
	HearthBeater *HearthBeater
	JobProcessor *JobProcessor
	Config       Config
}

type Config struct {
	Endpoint           string
	RegisterRetryLimit int
}

func Start(config Config, logger io.Writer) (*Listener, error) {
	listener := &Listener{Config: config}
	listener.DisplayHelloMessage()

	fmt.Println("* Starting Agent")
	fmt.Println("* Registering Agent")
	err := listener.Register()
	if err != nil {
		return listener, err
	}

	fmt.Println("* Starting to Send HearthBeats")
	hbEndpoint := "http://" + listener.Config.Endpoint + "/hearthbeat"
	hearthbeater, err := StartHeartBeater(hbEndpoint)
	if err != nil {
		return listener, err
	}

	fmt.Println("* Starting to poll for jobs")
	jobProcessor, err := StartJobProcessor(listener.Config.Endpoint)
	if err != nil {
		return listener, err
	}

	listener.HearthBeater = hearthbeater
	listener.JobProcessor = jobProcessor

	fmt.Println("* Acquiring job...")

	return listener, nil
}

func (l *Listener) DisplayHelloMessage() {
	fmt.Println("                                      ")
	fmt.Println("                 00000000000          ")
	fmt.Println("               0000000000000000       ")
	fmt.Println("             00000000000000000000     ")
	fmt.Println("          00000000000    0000000000   ")
	fmt.Println("   11     00000000    11   000000000  ")
	fmt.Println(" 111111   000000   1111111   000000   ")
	fmt.Println("111111111    0   111111111     00     ")
	fmt.Println("  1111111111   1111111111             ")
	fmt.Println("    1111111111111111111               ")
	fmt.Println("      111111111111111                 ")
	fmt.Println("         111111111                    ")
	fmt.Println("                                      ")
}

func (l *Listener) Register() error {
	payload := bytes.NewBuffer([]byte("{}"))
	url := fmt.Sprintf("http://%s/register", l.Config.Endpoint)

	for i := 0; i < l.Config.RegisterRetryLimit; i++ {
		resp, err := http.Post(url, "application/json", payload)
		if err != nil {
			fmt.Println(err)
			continue
		}

		defer resp.Body.Close()
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			fmt.Println(err)
			continue
		}

		fmt.Println(body)
		return nil
	}

	return fmt.Errorf("failed to register agent")
}
