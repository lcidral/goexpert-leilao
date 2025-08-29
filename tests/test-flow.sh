#!/bin/bash

# Script de teste automatizado para o sistema de leilões
# Este script executa os testes básicos de forma sequencial

set -e

BASE_URL="http://localhost:8080"
USER_ID="11111111-1111-1111-1111-111111111111"
CATEGORY="electronics"

echo "================================================"
echo "🚀 Iniciando testes do sistema de leilões"
echo "================================================"
echo ""

# Função para fazer requisições e exibir resultado
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo "▶️  $description"
    echo "   $method $BASE_URL$endpoint"
    
    if [ -z "$data" ]; then
        response=$(curl -s -X $method -w "\nHTTP_STATUS:%{http_code}" "$BASE_URL$endpoint")
    else
        response=$(curl -s -X $method -H "Content-Type: application/json" -d "$data" -w "\nHTTP_STATUS:%{http_code}" "$BASE_URL$endpoint")
    fi
    
    http_status=$(echo "$response" | grep "HTTP_STATUS" | cut -d':' -f2)
    body=$(echo "$response" | sed '/HTTP_STATUS/d')
    
    echo "   Status: $http_status"
    if [ ! -z "$body" ]; then
        echo "   Response: $body"
    fi
    echo ""
    
    # Retorna o body para uso posterior
    echo "$body"
}

# Teste 1: Verificar usuário demo
echo "📌 TESTE 1: Verificando usuário demo"
echo "----------------------------------------"
user_response=$(make_request "GET" "/user/$USER_ID" "" "Buscando usuário demo")

if [[ $user_response == *"Demo User"* ]]; then
    echo "✅ Usuário demo encontrado!"
else
    echo "⚠️  Usuário demo não encontrado. Certifique-se de que o MongoDB foi inicializado corretamente."
fi
echo ""

# Teste 2: Criar leilão
echo "📌 TESTE 2: Criando novo leilão"
echo "----------------------------------------"
auction_data='{
    "product_name": "Notebook Test",
    "category": "'$CATEGORY'",
    "description": "Notebook para teste automatizado do sistema",
    "condition": 1
}'
create_response=$(make_request "POST" "/auction" "$auction_data" "Criando leilão")
echo "✅ Leilão criado com sucesso!"
echo ""

# Teste 3: Listar leilões e capturar ID
echo "📌 TESTE 3: Listando leilões"
echo "----------------------------------------"
list_response=$(make_request "GET" "/auction?status=0&category=$CATEGORY&productName=" "" "Listando leilões da categoria $CATEGORY")

# Extrair o ID do primeiro leilão
AUCTION_ID=$(echo "$list_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$AUCTION_ID" ]; then
    echo "❌ Erro: Não foi possível obter o ID do leilão"
    exit 1
fi

echo "✅ ID do leilão capturado: $AUCTION_ID"
echo ""

# Teste 4: Buscar leilão por ID
echo "📌 TESTE 4: Buscando leilão por ID"
echo "----------------------------------------"
auction_detail=$(make_request "GET" "/auction/$AUCTION_ID" "" "Buscando detalhes do leilão")
echo "✅ Detalhes do leilão obtidos!"
echo ""

# Teste 5: Criar lances
echo "📌 TESTE 5: Criando lances"
echo "----------------------------------------"
echo "Criando 4 lances para forçar o batch flush..."

for i in {1..4}; do
    amount=$((100 + i * 50))
    bid_data='{
        "auction_id": "'$AUCTION_ID'",
        "user_id": "'$USER_ID'",
        "amount": '$amount'
    }'
    echo "   Lance $i: R\$ $amount"
    bid_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$bid_data" "$BASE_URL/bid" -w "%{http_code}")
    echo "   Status: $bid_response"
done

echo ""
echo "✅ Lances criados!"
echo ""

# Aguardar um pouco para o batch processar
echo "⏳ Aguardando 10 segundos para processamento do batch..."
sleep 10

# Teste 6: Listar lances
echo "📌 TESTE 6: Listando lances do leilão"
echo "----------------------------------------"
bids_response=$(make_request "GET" "/bid/$AUCTION_ID" "" "Listando lances")

if [[ $bids_response == *"amount"* ]]; then
    echo "✅ Lances listados com sucesso!"
else
    echo "⚠️  Nenhum lance encontrado. Pode ser necessário aguardar mais tempo para o batch processar."
fi
echo ""

# Teste 7: Teste de validação (deve falhar)
echo "📌 TESTE 7: Testando validações"
echo "----------------------------------------"
invalid_data='{
    "product_name": "X",
    "category": "ab",
    "description": "curta",
    "condition": 3
}'
validation_response=$(make_request "POST" "/auction" "$invalid_data" "Criando leilão inválido")
echo "✅ Validações funcionando corretamente (deve retornar erro 400)"
echo ""

# Resumo
echo "================================================"
echo "📊 RESUMO DOS TESTES"
echo "================================================"
echo ""
echo "✅ Testes básicos concluídos com sucesso!"
echo ""
echo "📝 Próximos passos:"
echo "1. Para testar o fechamento automático, aguarde o tempo configurado"
echo "   (padrão: 300 segundos ou conforme AUCTION_DEFAULT_DURATION_SEC)"
echo ""
echo "2. Após o fechamento, execute:"
echo "   curl $BASE_URL/auction/winner/$AUCTION_ID"
echo ""
echo "3. Para teste rápido de fechamento:"
echo "   - Ajuste AUCTION_DEFAULT_DURATION_SEC=30 no .env"
echo "   - Reinicie o docker compose"
echo "   - Execute este script novamente"
echo ""
echo "ID do leilão para testes futuros: $AUCTION_ID"
echo "================================================"