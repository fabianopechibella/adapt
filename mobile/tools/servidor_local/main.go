// Servidor local do pacote de demonstração: serve a pasta "web" ao lado do
// executável em http://127.0.0.1 e abre o navegador. Sem dependências.
package main

import (
	"errors"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"
)

func main() {
	porta := flag.Int("porta", 8080, "porta inicial; se ocupada, tenta as 20 seguintes")
	semNavegador := flag.Bool("sem-navegador", false, "não abre o navegador automaticamente")
	pasta := flag.String("pasta", "", "pasta com o build web (padrão: ./web ao lado do executável)")
	rede := flag.Bool("rede", false, "aceita conexões da rede local (para abrir no celular no mesmo Wi-Fi)")
	flag.Parse()

	dir, err := pastaWeb(*pasta)
	if err != nil {
		falhar(err)
	}

	host := "127.0.0.1"
	if *rede {
		host = "0.0.0.0"
	}
	ln, err := escutar(host, *porta)
	if err != nil {
		falhar(err)
	}
	p := ln.Addr().(*net.TCPAddr).Port
	url := fmt.Sprintf("http://127.0.0.1:%d/", p)

	fmt.Println("Autopeças Oficina · modo demonstração")
	fmt.Println("Abra no navegador:", url)
	if *rede {
		ips := ipsLocais()
		for _, ip := range ips {
			fmt.Printf("No celular (mesmo Wi-Fi): http://%s:%d/\n", ip, p)
		}
		if len(ips) == 0 {
			fmt.Printf("No celular: use http://<IP deste computador no Wi-Fi>:%d/ (veja o IP nas configurações de rede)\n", p)
		}
	}
	fmt.Println("Para encerrar, feche esta janela ou pressione Ctrl+C.")

	if !*semNavegador {
		go func() {
			time.Sleep(400 * time.Millisecond)
			abrirNavegador(url)
		}()
	}

	srv := &http.Server{Handler: semCache(http.FileServer(http.Dir(dir))), ReadHeaderTimeout: 10 * time.Second}
	if err := srv.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
		falhar(err)
	}
}

// Procura ./web ao lado do executável e, como alternativa, no diretório atual.
func pastaWeb(informada string) (string, error) {
	candidatas := []string{informada}
	if exe, err := os.Executable(); err == nil {
		candidatas = append(candidatas, filepath.Join(filepath.Dir(exe), "web"))
	}
	candidatas = append(candidatas, "web")
	for _, c := range candidatas {
		if c == "" {
			continue
		}
		if _, err := os.Stat(filepath.Join(c, "index.html")); err == nil {
			return c, nil
		}
	}
	return "", errors.New("pasta 'web' não encontrada; mantenha o executável ao lado dela")
}

// Por padrão só aceita conexões da própria máquina; com --rede, da rede local.
func escutar(host string, inicial int) (net.Listener, error) {
	for p := inicial; p <= inicial+20; p++ {
		if ln, err := net.Listen("tcp", fmt.Sprintf("%s:%d", host, p)); err == nil {
			return ln, nil
		}
	}
	return nil, fmt.Errorf("nenhuma porta livre entre %d e %d", inicial, inicial+20)
}

// Endereços IPv4 privados da máquina, para mostrar o link do celular.
func ipsLocais() []string {
	var ips []string
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return ips
	}
	for _, a := range addrs {
		if ipnet, ok := a.(*net.IPNet); ok && ipnet.IP.IsPrivate() && ipnet.IP.To4() != nil {
			ips = append(ips, ipnet.IP.String())
		}
	}
	return ips
}

// Evita que o navegador use uma versão antiga do app depois de atualizar o pacote.
func semCache(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}

func abrirNavegador(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	case "darwin":
		cmd = exec.Command("open", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	if err := cmd.Start(); err != nil {
		fmt.Println("Não consegui abrir o navegador; abra o endereço acima manualmente.")
	}
}

func falhar(err error) {
	fmt.Fprintln(os.Stderr, "Erro:", err)
	if runtime.GOOS == "windows" {
		fmt.Println("Pressione Enter para fechar.")
		fmt.Scanln()
	}
	os.Exit(1)
}
