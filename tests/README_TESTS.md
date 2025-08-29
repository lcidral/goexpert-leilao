# Guia de Execução dos Testes HTTP

Este guia explica como executar os testes HTTP de forma sequencial para validar o funcionamento completo da API de leilões.

## Pré-requisitos

1. **Ambiente em execução**: Os serviços devem estar rodando via Docker Compose
   ```bash
   docker compose up -d --build
   ```

2. **Cliente HTTP**: Use um dos seguintes:
   - VS Code com extensão REST Client
   - IntelliJ/GoLand com HTTP Client integrado
   - Postman (importe os arquivos .http manualmente)

## Sequência de Execução dos Testes

### 1. Teste de Criação de Leilão (01_auction_create.http)
- **Objetivo**: Criar um novo leilão válido
- **Resposta esperada**: HTTP 201 Created
- **Ação pós-teste**: Nenhuma (o ID será obtido no próximo teste)

### 2. Listagem por Categoria (02_auction_list_by_category.http)
- **Objetivo**: Listar leilões da categoria "electronics"
- **Resposta esperada**: HTTP 200 com array de leilões
- **IMPORTANTE**: Copie o ID do leilão criado no teste anterior
- **Exemplo de resposta**:
  ```json
  [{
    "id": "abc123-def456-...",
    "product_name": "Notebook Gamer Dell",
    "category": "electronics",
    ...
  }]
  ```

### 3. Busca por ID (03_auction_get_by_id.http)
- **Pré-requisito**: Substitua `SUBSTITUA_PELO_ID_DO_TESTE_02` pelo ID copiado
- **Objetivo**: Verificar detalhes do leilão específico
- **Resposta esperada**: HTTP 200 com dados do leilão

### 4. Teste de Validação (05_auction_create_invalid.http)
- **Objetivo**: Verificar validações da API
- **Resposta esperada**: HTTP 400 Bad Request
- **Pode ser executado a qualquer momento**

### 5. Criação de Lances (06_bid_create.http)
- **Pré-requisito**: Substitua `SUBSTITUA_PELO_ID_DO_TESTE_02` pelo ID do leilão
- **Objetivo**: Criar lances no leilão
- **IMPORTANTE**: Execute 4 vezes rapidamente OU aguarde 20 segundos
  - Isso é necessário devido ao sistema de batch (MAX_BATCH_SIZE=4)
- **Resposta esperada**: HTTP 201 Created

### 6. Listagem de Lances (07_bid_list_by_auction.http)
- **Pré-requisito**: Substitua o ID do leilão
- **Objetivo**: Verificar lances criados
- **Nota**: Se não aparecerem lances:
  - Aguarde 20 segundos (BATCH_INSERT_INTERVAL)
  - Ou execute o teste 06 mais vezes até completar 4 execuções

### 7. Teste de Usuário (08_user_get_by_id.http)
- **Objetivo**: Verificar usuário demo criado automaticamente
- **Resposta esperada**: HTTP 200 com dados do usuário
- **Pode ser executado a qualquer momento**

### 8. Consulta de Vencedor (04_auction_get_winner.http)
- **Pré-requisito**: Substitua o ID do leilão
- **Objetivo**: Verificar vencedor após fechamento automático
- **Nota**: Execute após o leilão ser fechado automaticamente
  - Por padrão, leilões duram 300 segundos (5 minutos)
  - Para testes rápidos, ajuste `AUCTION_DEFAULT_DURATION_SEC` para 30 segundos

## Testando o Fechamento Automático

Para testar o fechamento automático rapidamente:

1. **Ajuste o tempo de duração** no arquivo `cmd/auction/.env`:
   ```env
   AUCTION_DEFAULT_DURATION_SEC=30
   ```

2. **Reinicie os serviços**:
   ```bash
   docker compose down
   docker compose up -d --build
   ```

3. **Execute os testes 1-6** conforme descrito acima

4. **Aguarde 30 segundos** e execute o teste 03 novamente
   - O status deve mudar de 1 (Active) para 0 (Completed)

5. **Execute o teste 04** para ver o vencedor

## Solução de Problemas

### Lances não aparecem na listagem
- Aguarde 20 segundos (intervalo de batch)
- Ou execute o teste de criação de lance 4 vezes rapidamente

### Usuário não encontrado (teste 08)
- Limpe os volumes e reinicie:
  ```bash
  docker compose down -v
  docker compose up -d --build
  ```

### Leilão não fecha automaticamente
- Verifique os logs: `docker compose logs -f app`
- Confirme as variáveis de ambiente em `cmd/auction/.env`
- O worker deve logar "auto-close scan complete" periodicamente

### Erro de conexão
- Verifique se os serviços estão rodando: `docker compose ps`
- Confirme que a porta 8080 está livre
- Verifique os logs: `docker compose logs`

## Variáveis de Ambiente Importantes

```env
# Duração padrão de um leilão (segundos)
AUCTION_DEFAULT_DURATION_SEC=300

# Intervalo de verificação para fechamento (millisegundos)
AUCTION_CLOSE_SCAN_INTERVAL_MS=1000

# Configurações de batch para lances
MAX_BATCH_SIZE=4
BATCH_INSERT_INTERVAL=20s
```

## Ordem Recomendada Completa

1. ✅ Subir ambiente: `docker compose up -d --build`
2. ✅ Teste 08: Verificar usuário demo
3. ✅ Teste 01: Criar leilão
4. ✅ Teste 02: Listar e copiar ID
5. ✅ Teste 03: Verificar leilão criado
6. ✅ Teste 05: Testar validações (opcional)
7. ✅ Teste 06: Criar lances (4x ou aguardar)
8. ✅ Teste 07: Verificar lances
9. ⏳ Aguardar fechamento automático
10. ✅ Teste 04: Verificar vencedor

## Resultado Esperado

Após executar todos os testes na sequência correta:
- Um leilão será criado com sucesso
- Lances serão registrados no leilão
- O leilão será fechado automaticamente após o tempo configurado
- O vencedor será o lance de maior valor
- Todas as validações funcionarão corretamente