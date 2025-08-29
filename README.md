# Labs Auction GoExpert — Sistema de Leilões com Fechamento Automático

Este projeto implementa uma API REST completa de leilões em Go, com funcionalidade de fechamento automático através de goroutines. Desenvolvido como parte do desafio do curso GoExpert da FullCycle.

## 🚀 Quick Start - Início Rápido

```bash
# 1. Clone o repositório
git clone <url-do-repositorio>
cd labs-auction-goexpert

# 2. Copie o arquivo de configuração
cp cmd/auction/.env.example cmd/auction/.env

# 3. Suba o ambiente com Docker
docker compose up -d --build

# 4. Verifique se está funcionando
curl http://localhost:8080/user/11111111-1111-1111-1111-111111111111
```

Se tudo estiver correto, você receberá:
```json
{"id":"11111111-1111-1111-1111-111111111111","name":"Demo User"}
```

## 📋 Pré-requisitos
- Docker (v20+ recomendado)
- Docker Compose (v2 integrado ao Docker Desktop)
- Cliente HTTP para testes (VS Code REST Client, Postman, ou similar)

## 🏗️ Arquitetura do Projeto

### Estrutura de Serviços
- **API Go** (porta 8080): Aplicação principal com endpoints REST
- **MongoDB** (porta 27017): Banco de dados NoSQL para persistência
- **Worker de Fechamento**: Goroutine que verifica e fecha leilões expirados automaticamente

### Funcionalidades Implementadas
✅ Criação de leilões com validação  
✅ Listagem de leilões por categoria e status  
✅ Criação de lances (bids) com sistema de batch  
✅ **Fechamento automático de leilões por goroutine**  
✅ Consulta de vencedor após fechamento  
✅ Sistema de usuários com seed automático

## Variáveis de ambiente
A API e o MongoDB usam variáveis carregadas de cmd/auction/.env. Um exemplo está em `.env.example`.

Principais variáveis:
- MONGODB_URL: string de conexão do MongoDB (ex.: mongodb://admin:admin@mongodb:27017/auctions?authSource=admin)
- MONGODB_DB: nome do banco (ex.: auctions)
- AUCTION_DEFAULT_DURATION_SEC: duração padrão (em segundos) de um leilão recém‑criado (default sugerido: 300)
- AUCTION_CLOSE_SCAN_INTERVAL_MS: intervalo (ms) para o worker de fechamento automático varrer e encerrar leilões expirados (default sugerido: 1000)

Outras (aparecem no exemplo):
- BATCH_INSERT_INTERVAL, MAX_BATCH_SIZE, AUCTION_INTERVAL (usadas por partes do código conforme a evolução das tarefas/documentação)
- MONGO_INITDB_ROOT_USERNAME, MONGO_INITDB_ROOT_PASSWORD (usadas pelo container do MongoDB)

## Preparando o ambiente
1. Copie o arquivo de exemplo de variáveis e ajuste se necessário:
   cp cmd/auction/.env.example cmd/auction/.env
2. Revise e ajuste as variáveis em cmd/auction/.env se necessário.

Observação: o binário principal carrega variáveis a partir do caminho relativo `cmd/auction/.env`. O docker‑compose também referencia este mesmo arquivo via `env_file`.

## Subindo o ambiente com Docker Compose
Na raiz do projeto:
- Construir e subir em segundo plano:
  docker compose up -d --build
- Ver logs (todos os serviços):
  docker compose logs -f
- Ver logs apenas da API:
  docker compose logs -f app
- Parar e remover containers, rede e volumes nomeados (cuidado: apaga dados do MongoDB):
  docker compose down -v

O serviço da API ficará disponível em http://localhost:8080

## Executando testes com Docker
Se o projeto possuir testes Go, você pode executá‑los dentro do container da aplicação:
- Executar testes de todos os pacotes:
  docker compose run --rm app go test ./...
- Executar com cobertura:
  docker compose run --rm app sh -lc "go test ./... -cover"

## Rodando localmente sem Docker (opcional)
Se você tiver o Go instalado e um MongoDB local, configure as variáveis e rode:
- Copie e ajuste o .env como explicado acima.
- Suba um MongoDB localmente (ou use Docker apenas para o Mongo):
  docker run -d --name mongodb -p 27017:27017 -e MONGO_INITDB_ROOT_USERNAME=admin -e MONGO_INITDB_ROOT_PASSWORD=admin mongo:latest
- Exporte as variáveis de acordo com seu ambiente ou garanta que `cmd/auction/.env` está preenchido corretamente.
- Execute a API:
  go run ./cmd/auction

## Endpoints úteis (amostra)
- GET /auction — lista leilões
- GET /auction/:auctionId — detalhes do leilão
- POST /auction — cria um leilão
- GET /auction/winner/:auctionId — vencedor do leilão
- POST /bid — cria um lance
- GET /bid/:auctionId — lista lances por leilão
- GET /user/:userId — busca usuário

## 🧪 Executando os Testes Sequenciais

A pasta `tests/` contém 8 arquivos `.http` que devem ser executados em sequência para validar todo o fluxo da aplicação.

### Sequência Completa de Testes:

```bash
# 1. Verifique se o ambiente está rodando
docker compose ps

# 2. Execute os testes na seguinte ordem:
```

1. **Teste 08** - Verificar usuário demo (pode executar primeiro)
2. **Teste 01** - Criar um leilão
3. **Teste 02** - Listar leilões e **COPIAR O ID DO LEILÃO**
4. **Teste 03** - Buscar leilão por ID (substituir o ID)
5. **Teste 05** - Validações (opcional, pode executar a qualquer momento)
6. **Teste 06** - Criar lance (executar 4x rapidamente ou aguardar 20s)
7. **Teste 07** - Listar lances
8. **Aguardar fechamento** automático (300s por padrão ou 30s para teste rápido)
9. **Teste 04** - Verificar vencedor

### ⚠️ Importante sobre os Testes:

- **IDs**: Após criar um leilão (teste 01), você deve copiar o ID retornado no teste 02 e substituir `SUBSTITUA_PELO_ID_DO_TESTE_02` nos arquivos subsequentes
- **Batch de Lances**: Os lances são inseridos em lote. Execute o teste 06 quatro vezes rapidamente ou aguarde 20 segundos
- **Fechamento Automático**: Por padrão, leilões duram 5 minutos. Para teste rápido, ajuste `AUCTION_DEFAULT_DURATION_SEC=30` no `.env`

### 📖 Documentação Detalhada dos Testes

Consulte o arquivo `tests/README_TESTS.md` para instruções detalhadas sobre cada teste.

## Fluxo para testar o fechamento automático
1. Ajuste AUCTION_DEFAULT_DURATION_SEC para um valor baixo (ex.: 10) no `cmd/auction/.env`.
2. Suba/reinicie os serviços:
   docker compose up -d --build
3. Crie um leilão via POST /auction com os dados esperados (veja os controllers/usecases para o payload esperado).
4. Acompanhe os logs da API e/ou consulte o leilão após alguns segundos:
   - Logs: docker compose logs -f app
   - Consulta: GET /auction/:auctionId
5. O worker em background deve fechar automaticamente os leilões expirados, conforme o intervalo definido por AUCTION_CLOSE_SCAN_INTERVAL_MS.

## Troubleshooting
- Erro ao conectar no MongoDB: verifique MONGODB_URL, usuário/senha e se o serviço `mongodb` está UP (docker compose ps).
- Variáveis de ambiente não carregadas: confirme se `cmd/auction/.env` existe no container (o compose injeta via `env_file`) e se o caminho usado em `godotenv.Load("cmd/auction/.env")` está correto para sua forma de execução.
- Porta 8080 ocupada: altere o mapeamento no docker‑compose.yml ou pare o processo que ocupa a porta.
- Se o teste 08_user_get_by_id.http retornar 404, garanta que o Mongo foi inicializado com o script de seed:
  - O docker-compose monta ./docker/mongo-init em /docker-entrypoint-initdb.d do container do Mongo.
  - O script de seed roda somente na primeira inicialização do volume de dados. Se você já tinha dados, remova o volume para rodar o seed novamente: `docker compose down -v` e depois `docker compose up -d --build`.

## Licença
Uso educacional/laboratorial.
