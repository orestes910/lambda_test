package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
)

type Weather struct {
	current string
}

func main() {
	resp, respErr := http.Get("api.openweathermap.org/data/2.5/weather?zip=80401&APPID=699d450b072c35858db90d31b95e0fc0")
	if respErr != nil {
		log.Fatal("Request failed")
	}
	data, _ := ioutil.ReadAll(resp.Body)
	var jsonData Weather
	json.Unmarshal(data, &jsonData)
}
