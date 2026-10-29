#!/bin/bash

# Exit imediatamente se qualquer comando falhar
set -e

# =============================================================================
# CONFIGURAÇÃO DE CAMINHO MANUAL (FALLBACK)
# Se o script não conseguir fisgar o cartão sozinho, comente a linha abaixo
# e coloque o caminho exato onde o Ubuntu montou o cartão de 2GB.
# Exemplo: MANUAL_SD_PATH="/media/rafa/MEU_SD"
# =============================================================================
MANUAL_SD_PATH=""

echo "========================================"
# 1. Pipeline de Compilação Padrão
echo "⚙️  Configurando e compilando OlhosCapolei..."
cmake -S . -B build
cmake --build build -t clean
cmake --build build

echo "========================================"
echo "✅ Compilação concluída com sucesso!"

# 2. Pipeline de Detecção Avançada
SD_PATH=""

if [ -n "$MANUAL_SD_PATH" ]; then
    SD_PATH="$MANUAL_SD_PATH"
else
    # Busca na árvore de montagem ativa por qualquer volume externo em /media ou /run/media
    SD_PATH=$(findmnt -ln -o TARGET | grep -E '^/(media|run/media|mnt)/' | head -n 1 || true)
fi

if [ -n "$SD_PATH" ]; then
    echo "💾 Dispositivo detectado em: $SD_PATH"
    
    # 3. Solução da Gambiarra: Forçar Remontagem em modo Read-Write (RW)
    echo "🔓 Remontando o cartão como Read-Write (Pode pedir sua senha do sudo)..."
    sudo mount -o remount,rw "$SD_PATH"
    
    # 4. Transferência Segura da ROM para a Raiz do SD Card
    if [ -f "build/OlhosCapolei.smc" ]; then
        echo "🚀 Enviando OlhosCapolei.smc para a raiz do cartão..."
        cp build/OlhosCapolei.smc "$SD_PATH/"
        
        # O comando sync força o Linux a descarregar o buffer de escrita imediatamente no hardware
        sync
        echo "🎉 ROM atualizada com sucesso no seu Everdrive!"
    else
        echo "❌ Erro: Arquivo build/OlhosCapolei.smc não foi encontrado."
    fi
else
    echo "⚠️  Não foi possível detectar o ponto de montagem automaticamente."
    echo "💡 DICA: Clique no ícone '2.0 GB Volume' no seu gerenciador de arquivos,"
    echo "   depois abra o terminal e digite 'df -h' ou 'findmnt' para ver onde ele foi montado."
    echo "   Aí basta abrir este script e preencher a variável MANUAL_SD_PATH no topo!"
fi

echo "========================================"

