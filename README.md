# LPM Participatory Budgeting — Firebase

Board colaborativo para a dinâmica de **Participatory Budgeting** do treinamento LPM da SAI.
Funciona no navegador sem back-end próprio: usa **Firebase Realtime Database** para sincronização e presença em tempo real.

---

## Conteúdo do pacote

```
lpm-budget-firebase/
├── lpm-budget.html      ← aplicação principal (abra no navegador)
├── firebase-config.js   ← configurações do seu projeto Firebase (edite antes de rodar)
└── README.md            ← este guia
```

---

## Pré-requisitos

- Conta Google (para acessar o Firebase Console)
- Navegador moderno (Chrome, Edge, Firefox ou Safari recentes)
- Servidor HTTP local **ou** hospedagem (ver Passo 5)

> **Por que preciso de um servidor?**
> O arquivo `lpm-budget.html` usa `import` ES Modules (`type="module"`).
> Abrir o arquivo direto como `file://` bloqueia os imports — é necessário servir via `http://`.

---

## Passo 1 — Criar o projeto no Firebase

1. Acesse **[console.firebase.google.com](https://console.firebase.google.com)** e faça login.
2. Clique em **"Adicionar projeto"**.
3. Dê um nome ao projeto (ex.: `lpm-budget-sai`) e clique em **Continuar**.
4. Desative o Google Analytics se preferir e clique em **Criar projeto**.
5. Aguarde a criação e clique em **Continuar**.

---

## Passo 2 — Ativar o Realtime Database

1. No menu lateral, clique em **Build → Realtime Database**.
2. Clique em **"Criar banco de dados"**.
3. Escolha a localização mais próxima (ex.: `us-central1` ou `southamerica-east1`).
4. Na etapa de regras de segurança, selecione **"Iniciar no modo de teste"** → **Ativar**.

> O modo de teste permite leitura e escrita sem autenticação por **30 dias**, suficiente para workshops.
> Para uso em produção, veja a seção [Regras de segurança recomendadas](#regras-de-segurança-recomendadas) mais abaixo.

---

## Passo 3 — Registrar o app Web e obter as credenciais

1. Na página inicial do projeto, clique no ícone **`</>`** (Web).
2. Dê um apelido ao app (ex.: `lpm-budget-web`) e clique em **"Registrar app"**.
3. O Firebase exibirá um bloco `firebaseConfig` parecido com este:

```js
const firebaseConfig = {
  apiKey: "AIzaSy...",
  authDomain: "lpm-budget-sai.firebaseapp.com",
  databaseURL: "https://lpm-budget-sai-default-rtdb.firebaseio.com",
  projectId: "lpm-budget-sai",
  storageBucket: "lpm-budget-sai.appspot.com",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:web:abc123"
};
```

4. **Copie esses valores** — você vai precisar deles no próximo passo.
5. Clique em **"Continuar no console"**.

---

## Passo 4 — Preencher o arquivo `firebase-config.js`

Abra o arquivo `firebase-config.js` em qualquer editor de texto e substitua cada placeholder pelo valor copiado no passo anterior:

```js
// firebase-config.js
export const FIREBASE_CONFIG = {
  apiKey: 'AIzaSy...',                                          // ← cole aqui
  authDomain: 'lpm-budget-sai.firebaseapp.com',                // ← cole aqui
  databaseURL: 'https://lpm-budget-sai-default-rtdb.firebaseio.com', // ← cole aqui
  projectId: 'lpm-budget-sai',                                 // ← cole aqui
  storageBucket: 'lpm-budget-sai.appspot.com',                 // ← cole aqui
  messagingSenderId: '123456789012',                           // ← cole aqui
  appId: '1:123456789012:web:abc123'                           // ← cole aqui
}
```

> **Atenção:** não apague a função `validateFirebaseConfig` que está abaixo do objeto — ela é usada pelo app para verificar se a configuração está correta antes de conectar.

Salve o arquivo.

---

## Passo 5 — Rodar o app localmente

Você precisa servir os arquivos por HTTP. Escolha uma das opções abaixo:

### Opção A — VS Code + extensão Live Server *(recomendado para não-desenvolvedores)*

1. Instale o [VS Code](https://code.visualstudio.com/).
2. Instale a extensão **Live Server** (por Ritwick Dey).
3. Abra a pasta do projeto no VS Code.
4. Clique com o botão direito em `lpm-budget.html` → **"Open with Live Server"**.
5. O navegador abrirá automaticamente em `http://127.0.0.1:5500/lpm-budget.html`.

### Opção B — Python (se já tiver instalado)

```bash
# Python 3
python -m http.server 8080
```

Acesse `http://localhost:8080/lpm-budget.html`.

### Opção C — Node.js (se já tiver instalado)

```bash
npx serve .
```

Acesse a URL exibida no terminal.

---

## Passo 6 — Compartilhar com os participantes

Para que outros participantes se conectem à **mesma sala**:

1. Com o app aberto, clique em **"Compartilhar sala"** — o link da sala é copiado automaticamente.
2. Envie o link pelo chat ou projetor.

> Se você estiver rodando **localmente** (`localhost`), o link só funciona na **sua máquina**.
> Para compartilhar com outros dispositivos, use a hospedagem no Firebase (veja abaixo).

---

## (Opcional) Passo 7 — Hospedar no Firebase Hosting

Para que todos acessem via internet sem precisar instalar nada:

```bash
# Instale as ferramentas do Firebase (uma vez)
npm install -g firebase-tools

# Faça login
firebase login

# Na pasta do projeto, inicialize o Hosting
firebase init hosting
# → Use an existing project → selecione o projeto criado no Passo 1
# → Public directory: . (ponto)
# → Single-page app: N
# → Overwrite index.html: N

# Publique
firebase deploy --only hosting
```

O Firebase fornecerá uma URL pública no formato `https://lpm-budget-sai.web.app`.
Compartilhe essa URL com os participantes.

---

## Regras de segurança recomendadas

Para workshops internos o modo de teste é suficiente. Se precisar de mais controle, acesse **Realtime Database → Regras** e substitua pelo seguinte:

```json
{
  "rules": {
    "rooms": {
      "$roomId": {
        ".read": true,
        ".write": true,
        "boardState": {
          ".validate": "newData.hasChildren(['budget', 'epics', 'strategicThemes', 'revision'])"
        },
        "presence": {
          "$sessionId": {
            ".validate": "newData.hasChildren(['name', 'color', 'online_at'])"
          }
        }
      }
    }
  }
}
```

---

## Estrutura de dados no Firebase

```
rooms/
└── {roomId}/
    ├── boardState/          ← estado completo do board (budget, epics, themes, activity)
    └── presence/
        └── {sessionId}/     ← { name, color, online_at } — removido automaticamente ao sair
```

---

## Solução de problemas

| Sintoma | Causa provável | Solução |
|---|---|---|
| Tela branca ao abrir o `.html` | Aberto como `file://` | Use um servidor HTTP (Passo 5) |
| "Preencha o firebase-config.js" | Placeholders não substituídos | Revise o Passo 4 |
| "Permission denied" no console | Regras do banco expiradas | Redefina as regras no Firebase Console |
| Participantes não aparecem | `databaseURL` incorreto | Confirme a URL do RTDB no console Firebase |
| Sala não sincroniza | Projeto errado no config | Verifique `projectId` e `databaseURL` |

---

## Capacidade recomendada

| Recurso | Limite |
|---|---|
| Participantes por sala | 10 (configurável em `MAX_PARTICIPANTS`) |
| Salas simultâneas | Ilimitadas (dentro da cota gratuita do Firebase) |
| Atividades registradas por sala | 50 últimas ações |

O plano gratuito do Firebase (**Spark**) suporta confortavelmente sessões de treinamento com até centenas de usuários simultâneos.
