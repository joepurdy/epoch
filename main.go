package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

type Response struct {
	Message string `json:"The current epoch time"`
}

func handler(w http.ResponseWriter, r *http.Request) {
	epochTime := time.Now().Unix()
	response := Response{Message: fmt.Sprintf("%d", epochTime)}

	msg, err := json.Marshal(response)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(msg)
}

func main() {
	http.HandleFunc("/", handler)

	log.Println("Listening on :1337")
	err := http.ListenAndServe(":1337", nil)
	if err != nil {
		log.Fatal("Error serving: ", err)
	}
}
