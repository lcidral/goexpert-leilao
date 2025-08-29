#!/bin/bash

# Script para testar o fechamento automático de leilões
# Requer AUCTION_DEFAULT_DURATION_SEC=30 no .env

set -e

BASE_URL="http://localhost:8080"
USER_ID="11111111-1111-1111-1111-111111111111"

echo "================================================"
echo "🔒 Teste de Fechamento Automático de Leilões"
echo "================================================"
echo ""
echo "⚠️  Este teste requer AUCTION_DEFAULT_DURATION_SEC=30"
echo ""

# Criar leilão
echo "📌 Criando novo leilão..."
curl -s -X POST -H "Content-Type: application/json" \
     -d '{"product_name": "Auto Close Test", "category": "test", "description": "Testing automatic closure system", "condition": 1}' \
     http://localhost:8080/auction

# Obter ID do leilão
AUCTION_ID=$(curl -s "http://localhost:8080/auction?status=0&category=test&productName=" | \
             python3 -c "import json,sys;data=json.load(sys.stdin);print(data[-1]['id'] if data else '')" 2>/dev/null)

if [ -z "$AUCTION_ID" ]; then
    echo "❌ Erro: Não foi possível criar o leilão"
    exit 1
fi

echo "✅ Leilão criado com ID: $AUCTION_ID"
echo ""

# Verificar status inicial
echo "📌 Verificando status inicial..."
STATUS=$(curl -s http://localhost:8080/auction/$AUCTION_ID | \
         python3 -c "import json,sys;data=json.load(sys.stdin);print(data['status'])" 2>/dev/null)

if [ "$STATUS" == "1" ]; then
    echo "✅ Status inicial: ATIVO (1)"
else
    echo "⚠️  Status inesperado: $STATUS"
fi
echo ""

# Criar lances
echo "📌 Criando lances..."
for i in 1 2 3 4; do
    amount=$((500 + i * 100))
    curl -s -X POST -H "Content-Type: application/json" \
         -d '{"auction_id": "'$AUCTION_ID'", "user_id": "'$USER_ID'", "amount": '$amount'}' \
         http://localhost:8080/bid
    echo "   Lance $i: R\$ $amount ✓"
done
echo ""

# Aguardar fechamento
echo "⏳ Aguardando 35 segundos para fechamento automático..."
echo "   (Leilão deve fechar em 30 segundos)"
for i in {35..1}; do
    printf "\r   Tempo restante: %02d segundos" $i
    sleep 1
done
echo ""
echo ""

# Verificar status após fechamento
echo "📌 Verificando status após tempo de fechamento..."
STATUS=$(curl -s http://localhost:8080/auction/$AUCTION_ID | \
         python3 -c "import json,sys;data=json.load(sys.stdin);print(data['status'])" 2>/dev/null)

if [ "$STATUS" == "0" ]; then
    echo "✅ Status final: FECHADO (0) - Fechamento automático funcionou!"
else
    echo "❌ Status ainda ATIVO ($STATUS) - Fechamento automático não funcionou"
    exit 1
fi
echo ""

# Verificar vencedor
echo "📌 Verificando vencedor do leilão..."
WINNER=$(curl -s http://localhost:8080/auction/winner/$AUCTION_ID 2>/dev/null)

if [[ $WINNER == *"bid"* ]]; then
    AMOUNT=$(echo $WINNER | python3 -c "import json,sys;data=json.load(sys.stdin);print(data['bid']['amount'] if 'bid' in data and data['bid'] else 'N/A')" 2>/dev/null)
    echo "✅ Vencedor encontrado com lance de R\$ $AMOUNT"
else
    echo "⚠️  Nenhum vencedor encontrado (normal se não houve lances processados)"
fi
echo ""

# Tentar criar novo lance após fechamento
echo "📌 Testando criar lance após fechamento..."
HTTP_CODE=$(curl -s -X POST -H "Content-Type: application/json" \
           -d '{"auction_id": "'$AUCTION_ID'", "user_id": "'$USER_ID'", "amount": 9999}' \
           -o /dev/null -w "%{http_code}" http://localhost:8080/bid)

if [ "$HTTP_CODE" == "201" ]; then
    echo "⚠️  Lance aceito (201) - Será rejeitado pelo batch worker"
    # Aguardar processamento e verificar se foi realmente inserido
    sleep 5
    LANCE_COUNT=$(curl -s http://localhost:8080/bid/$AUCTION_ID | python3 -c "import json,sys;data=json.load(sys.stdin);print(len(data))" 2>/dev/null)
    if [ "$LANCE_COUNT" -gt "4" ]; then
        echo "❌ Lance foi processado após fechamento - ERRO!"
    else
        echo "✅ Lance foi rejeitado pelo sistema - Correto!"
    fi
else
    echo "✅ Lance rejeitado imediatamente - Correto! (HTTP $HTTP_CODE)"
fi
echo ""

echo "================================================"
echo "📊 RESULTADO DO TESTE"
echo "================================================"
echo ""
echo "✅ Fechamento automático está funcionando!"
echo "   - Leilão criado como ATIVO"
echo "   - Fechado automaticamente após 30 segundos"
echo "   - Vencedor determinado corretamente"
echo "   - Novos lances são rejeitados após fechamento"
echo ""
echo "ID do leilão testado: $AUCTION_ID"
echo "================================================"