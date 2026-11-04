#!/bin/bash

# Exit imediatamente se qualquer comando falhar
set -e

# 1. Gera o sufixo temporal baseado apenas em Hora e Minuto (HHMM)
TIMESTAMP=$(date +"%H%M")

echo "========================================"
echo "⚙️  Configurando e compilando OlhosCapolei [Build: $TIMESTAMP]..."
echo "========================================"

cmake -S . -B build
cmake --build build -t clean
cmake --build build

echo "========================================"
echo "✅ Compilação concluída com sucesso!"

# =============================================================================
# 🌐 PIPELINE: DEPLOY DE ROM PARA O SITE (NOME LIMPO)
# =============================================================================
TARGET_SITE_DIR="Site/roms"

if [ -f "build/OlhosCapolei.smc" ]; then
    echo "📂 Organizando diretório do site..."
    mkdir -p "$TARGET_SITE_DIR"
    
    # Define o nome limpo e estático para a pasta do site
    CLEAN_NAME="OlhosCapolei.smc"
    
    echo "🌐 Enviando $CLEAN_NAME para a pasta $TARGET_SITE_DIR..."
    cp build/OlhosCapolei.smc "$TARGET_SITE_DIR/$CLEAN_NAME"
else
    echo "❌ Erro: Arquivo build/OlhosCapolei.smc não foi encontrado."
    exit 1
fi

# =============================================================================
# 💾 PIPELINE: DETECÇÃO AVANÇADA DE SD CARD (EVERDRIVE COM TIMESTAMP)
# =============================================================================
SD_PATH=$(findmnt -ln -o TARGET | grep -E '^/(media|run/media|mnt)/' | head -n 1 || true)

if [ -n "$SD_PATH" ]; then
    echo "💾 Dispositivo detectado em: $SD_PATH"
    
    echo "🔓 Remontando o cartão como Read-Write..."
    sudo mount -o remount,rw "$SD_PATH"
    
    echo "🧹 Limpando builds antigos do OlhosCapolei do cartão..."
    rm -f "$SD_PATH"/OlhosCapolei*
    
    # Define o nome com timestamp para controle no Everdrive
    TARGET_NAME="OlhosCapolei_$TIMESTAMP.smc"
    echo "🚀 Enviando $TARGET_NAME para a raiz do cartão..."
    cp build/OlhosCapolei.smc "$SD_PATH/$TARGET_NAME"
    
    # O comando sync força o Linux a descarregar o buffer de escrita no hardware físico
    sync
    echo "🎉 ROM $TARGET_NAME atualizada com sucesso no seu Everdrive!"
else
    echo "⚠️  Não foi possível detectar o SD Card automaticamente."
fi

echo "========================================"

