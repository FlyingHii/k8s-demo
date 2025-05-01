package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()
	r.GET("/", func(c *gin.Context) {
		c.String(http.StatusOK, "Hello, Kubernetes from Gin Gonic!")
	})

	// Listen and serve on 0.0.0.0:8080
	r.Run(":8080")
}
