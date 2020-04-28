package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const requests_filename = "lb_requests.csv"
const unicornWorkers = 16
const unicornRequestBufferSize = 100

var unicornId = 0

type Request struct {
	OriginalStartTime time.Time
	StartTime         time.Time
	EndTime           time.Time
	Latency           time.Duration
	UnicornId         int
}

type Response struct {
	Request     *Request
	Utilization float32
}

type Unicorn struct {
	Id           int
	responseChan chan *Response
	requestChan  chan *Request
	workingCount int32
	waitGroup    *sync.WaitGroup
}

func NewUnicorn(responseChan chan *Response) *Unicorn {
	unicornId += 1
	return &Unicorn{
		Id:           unicornId,
		responseChan: responseChan,
	}
}

func (u *Unicorn) worker() {
	u.waitGroup.Add(1)
	defer u.waitGroup.Done()

	for r := range u.requestChan {
		atomic.AddInt32(&u.workingCount, 1)
		r.UnicornId = u.Id
		time.Sleep(r.Latency)
		r.EndTime = time.Now()
		atomic.AddInt32(&u.workingCount, -1)

		u.responseChan <- &Response{
			Request:     r,
			Utilization: u.Utilization(),
		}
	}
}

func (u *Unicorn) Start() {
	u.waitGroup = &sync.WaitGroup{}
	u.requestChan = make(chan *Request, unicornRequestBufferSize)

	for i := 0; i < unicornWorkers; i++ {
		go u.worker()
	}
}

func (u *Unicorn) Send(r *Request) bool {
	r.StartTime = time.Now()
	select {
	case u.requestChan <- r:
		return true
	default:
		return false
	}
}

func (u *Unicorn) Utilization() float32 {
	return float32(int(u.workingCount)+len(u.requestChan)) / float32(unicornWorkers)
}

func (u *Unicorn) Stop() {
	close(u.requestChan)
	u.waitGroup.Wait()
}

type Algorithm interface {
	Select(peers []*Unicorn) *Unicorn
	ProcessResponse(response *Response)
}

type RoundRobinAlgorithm struct {
	index int
}

func (rr *RoundRobinAlgorithm) Select(peers []*Unicorn) *Unicorn {
	rr.index += 1
	if rr.index >= len(peers) {
		rr.index = 0
	}
	return peers[rr.index]
}

func (rr *RoundRobinAlgorithm) ProcessResponse(_ *Response) {}

type LoadBalancer struct {
	numUnicorns  int
	Unicorns     []*Unicorn
	algorithm    Algorithm
	responseChan chan *Response
	sendErrors   uint
	stopChan     chan bool
}

func NewLoadBalancer(numUnicorns int, algorithm Algorithm) *LoadBalancer {
	return &LoadBalancer{
		numUnicorns: numUnicorns,
		algorithm:   algorithm,
	}
}

func (lb *LoadBalancer) responseHandler() {
	for r := range lb.responseChan {
		lb.algorithm.ProcessResponse(r)
	}
}

func (lb *LoadBalancer) utilizationMonitor() {
	for {
		select {
		case <-lb.stopChan:
			break
		case <-time.After(1 * time.Second):
			var b strings.Builder
			for _, u := range lb.Unicorns {
				fmt.Fprintf(&b, "%d=%f ", u.Id, u.Utilization())
			}
			fmt.Printf("%s %s\n", time.Now().Format(time.RFC3339Nano), b.String())
		}
	}
}

func (lb *LoadBalancer) Start() {
	lb.responseChan = make(chan *Response)
	lb.stopChan = make(chan bool)
	lb.Unicorns = make([]*Unicorn, lb.numUnicorns)

	for i := 0; i < lb.numUnicorns; i++ {
		unicorn := NewUnicorn(lb.responseChan)
		unicorn.Start()
		lb.Unicorns[i] = unicorn
	}

	go lb.responseHandler()
	go lb.utilizationMonitor()
}

func (lb *LoadBalancer) Stop() {
	for i := 0; i < lb.numUnicorns; i++ {
		lb.Unicorns[i].Stop()
	}
	close(lb.responseChan)
	close(lb.stopChan)
}

func (lb *LoadBalancer) Send(r *Request) {
	upstream := lb.algorithm.Select(lb.Unicorns)
	if !upstream.Send(r) {
		lb.sendErrors += 1
	}
}

type RequestDispatcher struct {
	requests []*Request
}

func LoadRequestsFromFile(filename string) *RequestDispatcher {
	file, err := os.Open(filename)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	requests := make([]*Request, 0)

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		parts := strings.Split(scanner.Text(), ",")
		startTime, err := time.Parse(time.RFC3339Nano, strings.Trim(parts[0], "\""))
		if err != nil {
			continue
		}

		latency, err := time.ParseDuration(strings.Trim(parts[1], "\"") + "s")
		if err != nil {
			continue
		}

		request := &Request{
			OriginalStartTime: startTime,
			Latency:           latency,
		}
		requests = append(requests, request)
	}

	return &RequestDispatcher{
		requests: requests,
	}
}

func (rd *RequestDispatcher) Execute(lb *LoadBalancer) {
	var lastRequest *Request
	for _, r := range rd.requests {
		if lastRequest != nil && r.OriginalStartTime != lastRequest.OriginalStartTime {
			time.Sleep(r.OriginalStartTime.Sub(lastRequest.OriginalStartTime))
		}
		lb.Send(r)
		lastRequest = r
	}
}

func main() {
	lb := NewLoadBalancer(50, &RoundRobinAlgorithm{})
	dispatcher := LoadRequestsFromFile(requests_filename)

	lb.Start()
	dispatcher.Execute(lb)
	fmt.Printf("Request execution completed. Shutting down ... ")

	lb.Stop()
	fmt.Printf("done.\n")
}
