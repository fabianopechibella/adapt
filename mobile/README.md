# Apps mobile: marketplace de autopeças para oficinas

Dois apps Flutter (um código para **iOS e Android**) e um pacote compartilhado, seguindo a
arquitetura C4 do case (contexto, contêineres, saga do pedido e agente de IA).

| App | Para quem | O que faz |
| --- | --- | --- |
| `apps/oficina` | Mecânico e comprador da oficina | Placa → veículo → peça compatível → ofertas ranqueadas → carrinho multifornecedor → pedido → acompanhamento da saga → devolução. Inclui o assistente de IA. |
| `apps/entregador` | Entregador parceiro | Rotas disponíveis → aceite → coleta (bloqueada sem NF-e) → rota → entrega com código da oficina. |
| `packages/autopecas_core` | Os dois apps | Domínio, regras da saga, ranking de ofertas, validadores, contrato HTTP, backends de demonstração e design system. |

O contrato com os BFFs está em [`api/openapi.yaml`](api/openapi.yaml).

## Como rodar

Pré-requisitos: Flutter 3.47 (Dart 3.13), Xcode para iOS e Android SDK para Android.

```bash
cd mobile
flutter pub get                      # resolve o workspace inteiro

cd apps/oficina
flutter run                          # modo demonstração (backend em memória)
flutter run --dart-define=API_BASE_URL=https://bff-oficina.exemplo.com.br
```

Sem `API_BASE_URL`, o app sobe em **modo demonstração**, com a faixa "DEMO" e estes dados:

- Oficina: CNPJ `11.222.333/0001-81`, qualquer celular, código `123456`.
- Placas: `ABC1D23` (Onix), `BRA2E19` (HB20), `QWE4R56` (Strada), `KJH5544` (Gol).
- A saga avança sozinha a cada 4 s. A primeira NF-e do distribuidor "Auto Norte" é
  rejeitada e reemitida, para mostrar a compensação.
- Entregador: qualquer CPF com 11 dígitos, código `123456`; código de entrega `2468`.
  A corrida da "Oficina Boa Vista" começa com a NF-e pendente, autorizada após 8 s.

## Como a arquitetura aparece no código

| Decisão do documento | Onde está |
| --- | --- |
| O LLM nunca decide compatibilidade; o grafo decide | O app só exibe `FitmentMatch.confidence`. Abaixo de 0,85 a tela de ofertas exige conferir o código da peça antes de liberar a compra (`offers_screen.dart`). |
| Guardrails do agente | `FakeAgent` reproduz o contrato do agente real: pede a placa, pede o código quando a confiança é baixa e transfere para humano na 2ª falha. O LLM roda no backend; nenhuma chave de modelo fica no app. |
| Saga com compensações e NF-e antes da coleta | `OrderStatus` e a tabela de transições (`order.dart`). `SubOrder.transition` recusa transições inválidas. `Delivery.advance` bloqueia a coleta sem NF-e. |
| Um subpedido por distribuidor | `Cart.byDistributor` → `PlaceOrderRequest` → `Order.subOrders`. |
| Idempotência no checkout | `Idempotency-Key` gerada uma vez por tentativa de compra e reaproveitada em retentativas (`cart_screen.dart`). |
| Ranking preço × prazo × confiabilidade | `rankOffers` com pesos configuráveis e selos "Recomendado", "Mais barato" e "Mais rápido". |
| Faturado com limite de crédito | `WorkshopAccount.canInvoice`; a opção só é habilitada quando o total cabe no limite. |
| CNPJ alfanumérico (vigente desde jul/2026) | `Cnpj.isValid` cobre o formato numérico e o alfanumérico. |
| Flutter para os apps (ADR 9) | Workspace Dart com um pacote de domínio compartilhado e dois apps. |

## Qualidade

```bash
dart format --set-exit-if-changed packages apps
(cd packages/autopecas_core && flutter analyze --fatal-infos && flutter test)
(cd apps/oficina && flutter analyze --fatal-infos && flutter test)
(cd apps/entregador && flutter analyze --fatal-infos && flutter test)
```

- **Núcleo (35 testes):** validadores, ranking, carrinho, máquina de estados da saga, regras
  da entrega, backend de demonstração (idempotência, compensação da NF-e, devolução e crédito),
  guardrails do agente e cliente HTTP com `MockClient`.
- **Oficina (4 testes de widget):** login, fluxo completo da placa à entrega, bloqueio por
  aplicação não confirmada e assistente.
- **Entregador (1 teste de widget):** coleta bloqueada sem NF-e e entrega com código inválido e válido.

O workflow `.github/workflows/mobile.yml` roda formato, análise e testes, e depois compila o
APK (Ubuntu) e o app de simulador iOS (macOS) de cada app.

## Emulador Android e simulador iOS

Cada app tem um teste de integração (`integration_test/demo_flow_test.dart`) que percorre o
modo demonstração e tira uma captura de cada tela:

```bash
cd apps/oficina   # ou apps/entregador
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/demo_flow_test.dart -d <id do emulador ou simulador>
# capturas em ./screenshots/
```

O workflow `.github/workflows/mobile-emulators.yml` faz isso em um emulador Pixel 7 com
Android 14 e em um simulador de iPhone, e publica as capturas como artefatos
(`<app>-android-screenshots` e `<app>-ios-screenshots`).

## Antes de ir para produção

- Persistir a sessão em armazenamento seguro (Keychain/Keystore) e renovar o token.
- Notificações push (APNs/FCM) para mudanças da saga, no lugar do polling.
- GPS em segundo plano no app do entregador, com as permissões de cada plataforma.
- Câmera para foto da peça (agente) e prova de entrega.
- Assinatura e publicação nas lojas (fastlane), crash reporting e analytics.
- Trocar o polling de pedido e corrida por SSE ou WebSocket quando o BFF publicar o stream.
