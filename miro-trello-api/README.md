# Miro-Trello API

API REST para integração bidirecional entre [Miro](https://miro.com) e [Trello](https://trello.com).

## Funcionalidades

- Listar quadros e itens do Miro
- Listar quadros, listas e cards do Trello
- Sincronizar sticky notes/cards do Miro → Trello
- Sincronizar cards do Trello → sticky notes no Miro
- Webhooks automáticos para sincronização em tempo real

## Instalação

```bash
cd miro-trello-api
npm install
cp .env.example .env
# Preencha as variáveis no .env
npm start
```

## Variáveis de Ambiente

| Variável | Descrição |
|---|---|
| `MIRO_ACCESS_TOKEN` | Token de acesso OAuth do Miro |
| `TRELLO_API_KEY` | Chave de API do Trello |
| `TRELLO_TOKEN` | Token de autorização do Trello |
| `MIRO_DEFAULT_BOARD_ID` | Board Miro padrão para webhooks |
| `TRELLO_DEFAULT_LIST_ID` | Lista Trello padrão para webhooks |
| `PORT` | Porta do servidor (padrão: 3000) |

### Como obter as credenciais

**Miro:**
1. Acesse [developers.miro.com](https://developers.miro.com)
2. Crie um app e gere um Access Token

**Trello:**
1. Acesse [trello.com/app-key](https://trello.com/app-key) para a API Key
2. Gere o token em: `https://trello.com/1/authorize?expiration=never&scope=read,write&response_type=token&key=SUA_API_KEY`

## Endpoints

### Miro

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/miro/boards` | Lista todos os quadros |
| GET | `/api/miro/boards/:boardId/items` | Lista itens de um quadro |
| POST | `/api/miro/boards/:boardId/sticky_notes` | Cria sticky note |
| PATCH | `/api/miro/boards/:boardId/sticky_notes/:itemId` | Atualiza sticky note |
| DELETE | `/api/miro/boards/:boardId/sticky_notes/:itemId` | Remove sticky note |
| POST | `/api/miro/boards/:boardId/cards` | Cria card no Miro |
| POST | `/api/miro/boards/:boardId/webhooks` | Registra webhook |

### Trello

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/trello/boards` | Lista todos os quadros |
| GET | `/api/trello/boards/:boardId` | Detalhes de um quadro |
| GET | `/api/trello/boards/:boardId/lists` | Lista as listas do quadro |
| GET | `/api/trello/boards/:boardId/cards` | Lista cards do quadro |
| POST | `/api/trello/cards` | Cria card |
| PUT | `/api/trello/cards/:cardId` | Atualiza card |
| DELETE | `/api/trello/cards/:cardId` | Remove card |
| POST | `/api/trello/boards/:boardId/lists` | Cria lista |
| POST | `/api/trello/webhooks` | Registra webhook |

### Sincronização

| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/sync/miro-to-trello` | Sincroniza itens do Miro → Trello |
| POST | `/api/sync/trello-to-miro` | Sincroniza cards do Trello → Miro |

### Webhooks (tempo real)

| Método | Rota | Descrição |
|---|---|---|
| POST | `/webhooks/miro` | Recebe eventos do Miro |
| POST | `/webhooks/trello` | Recebe eventos do Trello |

## Exemplos de Uso

### Sincronizar Miro → Trello

```bash
curl -X POST http://localhost:3000/api/sync/miro-to-trello \
  -H "Content-Type: application/json" \
  -d '{
    "miroBoardId": "SEU_BOARD_MIRO",
    "trelloListId": "SEU_LIST_TRELLO",
    "itemType": "sticky_note"
  }'
```

### Sincronizar Trello → Miro

```bash
curl -X POST http://localhost:3000/api/sync/trello-to-miro \
  -H "Content-Type: application/json" \
  -d '{
    "trelloBoardId": "SEU_BOARD_TRELLO",
    "miroBoardId": "SEU_BOARD_MIRO",
    "color": "light_blue"
  }'
```

### Criar card no Trello via API

```bash
curl -X POST http://localhost:3000/api/trello/cards \
  -H "Content-Type: application/json" \
  -d '{
    "idList": "SEU_LIST_ID",
    "name": "Novo Card",
    "desc": "Descrição do card"
  }'
```

### Criar sticky note no Miro via API

```bash
curl -X POST http://localhost:3000/api/miro/boards/SEU_BOARD_ID/sticky_notes \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Minha nota",
    "color": "yellow"
  }'
```
