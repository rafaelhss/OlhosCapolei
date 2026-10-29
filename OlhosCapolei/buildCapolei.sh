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

# 2. Pipeline de Detecção Avançada de SD Card
SD_PATH=$(findmnt -ln -o TARGET | grep -E '^/(media|run/media|mnt)/' | head -n 1 || true)

if [ -n "$SD_PATH" ]; then
    echo "💾 Dispositivo detectado em: $SD_PATH"
    
    echo "🔓 Remontando o cartão como Read-Write..."
    sudo mount -o remount,rw "$SD_PATH"
    
    # 3. Limpeza Preventiva: Deleta todas as ROMs antigas do projeto na raiz do SD
    echo "🧹 Limpando builds antigos do OlhosCapolei do cartão..."
    rm -f "$SD_PATH"/OlhosCapolei*
    
    if [ -f "build/OlhosCapolei.smc" ]; then
        # 4. Define o nome final usando o Timestamp HHMM gerado
        TARGET_NAME="OlhosCapolei_$TIMESTAMP.smc"
        echo "🚀 Enviando $TARGET_NAME para a raiz do cartão..."
        cp build/OlhosCapolei.smc "$SD_PATH/$TARGET_NAME"
        
        # O comando sync força o Linux a descarregar o buffer de escrita no hardware físico
        sync
        echo "🎉 ROM $TARGET_NAME atualizada com sucesso no seu Everdrive!"
    else
        echo "❌ Erro: Arquivo build/OlhosCapolei.smc não foi encontrado."
    fi
else
    echo "⚠️  Não foi possível detectar o SD Card automaticamente."
fi

echo "========================================"

