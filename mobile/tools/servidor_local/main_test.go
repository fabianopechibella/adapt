package main

import (
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"
)

func TestServeWebFolderWithWasmTypeAndNoCache(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "index.html"), []byte("<html>ok</html>"), 0o644)
	os.WriteFile(filepath.Join(dir, "motor.wasm"), []byte{0, 'a', 's', 'm'}, 0o644)

	got, err := pastaWeb(dir)
	if err != nil || got != dir {
		t.Fatalf("pastaWeb = %q, %v", got, err)
	}
	ln, err := escutar("127.0.0.1", 18080)
	if err != nil {
		t.Fatal(err)
	}
	srv := &http.Server{Handler: semCache(http.FileServer(http.Dir(dir)))}
	go srv.Serve(ln)
	defer srv.Close()
	base := "http://" + ln.Addr().String()

	res, err := http.Get(base + "/")
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(res.Body)
	res.Body.Close()
	if string(body) != "<html>ok</html>" || res.Header.Get("Cache-Control") != "no-store" {
		t.Fatalf("index: %q cache=%q", body, res.Header.Get("Cache-Control"))
	}

	res, err = http.Get(base + "/motor.wasm")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if ct := res.Header.Get("Content-Type"); ct != "application/wasm" {
		t.Fatalf("wasm servido como %q; o navegador exige application/wasm", ct)
	}
}

func TestEscutarSoNaMaquinaLocal(t *testing.T) {
	ln, err := escutar("127.0.0.1", 18100)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	host, _, _ := net.SplitHostPort(ln.Addr().String())
	if host != "127.0.0.1" {
		t.Fatalf("escutando em %s; deveria ser só 127.0.0.1", host)
	}
}

func TestPortaOcupadaUsaAProxima(t *testing.T) {
	primeiro, err := escutar("127.0.0.1", 18200)
	if err != nil {
		t.Fatal(err)
	}
	defer primeiro.Close()
	segundo, err := escutar("127.0.0.1", 18200)
	if err != nil {
		t.Fatal(err)
	}
	defer segundo.Close()
	if primeiro.Addr().String() == segundo.Addr().String() {
		t.Fatal("deveria ter usado outra porta")
	}
}

func TestSemPastaWebFalhaComMensagemClara(t *testing.T) {
	if _, err := pastaWeb(t.TempDir()); err == nil {
		t.Fatal("esperava erro sem index.html")
	}
}
