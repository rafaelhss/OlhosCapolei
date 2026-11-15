#!/bin/bash

# Exit imediatamente se qualquer comando falhar
set -e

# 1. Gera o sufixo temporal no formato DDMMYYhhmm (Dia, Mês, Ano, Hora, Minuto)
TIMESTAMP=$(date +"%d%m%y%H%M")
ROM_NAME="capolei${TIMESTAMP}.smc"

echo "========================================"
echo "⚙️  Configurando e compilando OlhosCapolei [Build: $ROM_NAME]..."
echo "========================================"

cmake -S . -B build
cmake --build build -t clean
cmake --build build

echo "========================================"
echo "✅ Compilação concluída com sucesso!!!!"

# --- RELATÓRIO DE OCUPAÇÃO DE MEMÓRIA ---
if [ -f "build/mapa.txt" ]; then
    echo "📊 Resumo de Ocupação de Memória:"
    grep -A 12 "Segment list:" build/mapa.txt
fi
# ----------------------------------------

echo "========================================"

# Verifica se a ROM foi gerada antes de prosseguir
if [ ! -f "build/OlhosCapolei.smc" ]; then
    echo "❌ Erro: Arquivo build/OlhosCapolei.smc não foi encontrado."
    exit 1
fi

# =============================================================================
# 🌐 PIPELINE: DEPLOY DE ROM E ATUALIZAÇÃO DO SITE (VIA COMMIT @SITE@)
# =============================================================================
TARGET_SITE_DIR="Site/roms"
HTML_FILE="Site/index.html"

# Captura o hash curto e a mensagem do último commit local
LAST_COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "")
LAST_COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")

if echo "$LAST_COMMIT_MSG" | grep -q "@SITE@"; then
    # 1. Bloqueia execução repetida do exato mesmo commit
    if [ -f "$HTML_FILE" ] && [ -n "$LAST_COMMIT_HASH" ] && grep -q "<!-- commit:${LAST_COMMIT_HASH} -->" "$HTML_FILE"; then
        echo "⏭️  O commit [$LAST_COMMIT_HASH] já foi publicado na tabela do site. Pulando..."
    else
        echo "🌐 Tag @SITE@ detectada no commit [$LAST_COMMIT_HASH]! Atualizando site..."
        
        # Copia a nova ROM para Site/roms
        mkdir -p "$TARGET_SITE_DIR"
        echo "📦 Enviando $ROM_NAME para $TARGET_SITE_DIR..."
        cp build/OlhosCapolei.smc "$TARGET_SITE_DIR/$ROM_NAME"

        # Atualiza o Site/index.html se ele existir
        if [ -f "$HTML_FILE" ]; then
            DATA_ATUAL=$(date +"%d-%m-%Y %H:%M")
            
            COMMIT_HASH="$LAST_COMMIT_HASH" \
            COMMIT_MSG="$LAST_COMMIT_MSG" \
            ROM_FILE="$ROM_NAME" \
            DATA_STR="$DATA_ATUAL" \
            HTML_PATH="$HTML_FILE" \
            ROMS_DIR="$TARGET_SITE_DIR" \
            python3 - << 'EOF'
import os
import re
import html

html_path = os.environ["HTML_PATH"]
roms_dir = os.environ["ROMS_DIR"]
commit_hash = os.environ["COMMIT_HASH"]
commit_msg = os.environ["COMMIT_MSG"]
rom_file = os.environ["ROM_FILE"]
data_str = os.environ["DATA_STR"]

# Remove @SITE@ e limpa quebras de linha/espaços extras
clean_comment = commit_msg.replace("@SITE@", "").strip()
clean_comment = re.sub(r'\s+', ' ', clean_comment)
if not clean_comment:
    clean_comment = "Nova atualização"
escaped_comment = html.escape(clean_comment)

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

tbody_match = re.search(r'(<tbody>)(.*?)(</tbody>)', content, flags=re.DOTALL | re.IGNORECASE)

if tbody_match:
    tbody_open = tbody_match.group(1)
    tbody_inner = tbody_match.group(2)
    tbody_close = tbody_match.group(3)
    
    # Captura todos os blocos de linha (com comentário <!-- commit:... --> opcional + <tr>...</tr>)
    row_pattern = re.compile(r'(\s*(?:<!--\s*commit:[^\s>]+\s*-->\s*)?<tr>.*?</tr>)', flags=re.DOTALL | re.IGNORECASE)
    rows = row_pattern.findall(tbody_inner)
    
    replaced = False
    new_rows = []
    
    for row in rows:
        tds = re.findall(r'<td[^>]*>(.*?)</td>', row, flags=re.DOTALL | re.IGNORECASE)
        if len(tds) >= 4:
            # Extrai o texto puro da coluna de comentário (2ª coluna)
            row_comment = html.unescape(re.sub(r'<[^>]+>', '', tds[1])).strip()
            row_comment = re.sub(r'\s+', ' ', row_comment)
            
            # Se o comentário for idêntico (ignorando maiúsculas/minúsculas), substitui o registro
            if not replaced and row_comment.lower() == clean_comment.lower():
                # Preserva o caminho da imagem original daquela linha
                img_match = re.search(r'src=["\']([^"\']+)["\']', tds[0], flags=re.IGNORECASE)
                img_src = img_match.group(1) if img_match else f"img/thumb{len(rows)}.jpeg"
                
                # Apaga a ROM antiga da pasta Site/roms para não sobrar lixo
                old_rom_match = re.search(r'\?rom=([^"\'>\s]+)', tds[3], flags=re.IGNORECASE)
                if old_rom_match:
                    old_rom_path = os.path.join(roms_dir, old_rom_match.group(1))
                    if os.path.exists(old_rom_path) and old_rom_match.group(1) != rom_file:
                        try:
                            os.remove(old_rom_path)
                            print(f"🧹 ROM antiga removida do site: {old_rom_match.group(1)}")
                        except OSError:
                            pass

                updated_row = f"""
        <!-- commit:{commit_hash} -->
        <tr>
            <td>
                <img src="{img_src}" width="100px" height="100px" >
            </td>
            <td>
                {escaped_comment}
            </td>
            <td>
                {data_str}
            </td>
            
            <td>
                <a href="play.html?rom={rom_file}">Play</a> 
            </td>
        </tr>"""
                new_rows.append(updated_row)
                replaced = True
                print(f"🔄 Comentário '{clean_comment}' já existia! Registro atualizado ({img_src} | {rom_file}).")
            else:
                new_rows.append(row)
        else:
            new_rows.append(row)
            
    if replaced:
        updated_tbody_inner = "".join(new_rows)
        # Garante uma quebra de linha limpa antes do </tbody>
        if not updated_tbody_inner.endswith("\n        "):
            updated_tbody_inner += "\n        "
        updated_tbody = tbody_open + updated_tbody_inner + tbody_close
    else:
        # Se for um comentário novo, cria nova linha no topo
        next_thumb_num = len(rows) + 1
        new_row = f"""
        <!-- commit:{commit_hash} -->
        <tr>
            <td>
                <img src="img/thumb{next_thumb_num}.jpeg" width="100px" height="100px" >
            </td>
            <td>
                {escaped_comment}
            </td>
            <td>
                {data_str}
            </td>
            
            <td>
                <a href="play.html?rom={rom_file}">Play</a> 
            </td>
        </tr>"""
        updated_tbody = tbody_open + new_row + tbody_inner + tbody_close
        print(f"✅ HTML atualizado!! Nova linha adicionada (img/thumb{next_thumb_num}.jpeg | {rom_file}).")
        print(f"📸 Lembrete: Salve a imagem deste build em Site/img/thumb{next_thumb_num}.jpeg")
        
    new_content = content[:tbody_match.start()] + updated_tbody + content[tbody_match.end():]
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(new_content)
else:
    print("⚠️  Aviso: Tag <tbody> não encontrada no index.html. O HTML não foi alterado.")
EOF
        else
            echo "⚠️  Arquivo $HTML_FILE não encontrado para atualização."
        fi
    fi
else
    echo "ℹ️  Tag @SITE@ não encontrada no último commit. Pulando atualização do site."
fi

# =============================================================================
# 💾 PIPELINE: DETECÇÃO AVANÇADA DE SD CARD (EVERDRIVE)
# =============================================================================
SD_PATH=$(findmnt -ln -o TARGET | grep -E '^/(media|run/media|mnt)/' | head -n 1 || true)

if [ -n "$SD_PATH" ]; then
    echo "💾 Dispositivo detectado em: $SD_PATH"
    
    echo "🔓 Remontando o cartão como Read-Write..."
    sudo mount -o remount,rw "$SD_PATH"
    
    echo "🧹 Limpando builds antigos do cartão..."
    rm -f "$SD_PATH"/OlhosCapolei* "$SD_PATH"/capolei*
    
    echo "🚀 Enviando $ROM_NAME para a raiz do cartão..."
    cp build/OlhosCapolei.smc "$SD_PATH/$ROM_NAME"
    
    # Força o Linux a descarregar o buffer de escrita no hardware físico
    sync
    echo "🎉 ROM $ROM_NAME atualizada com sucesso no seu Everdrive!"
else
    echo "⚠️  Não foi possível detectar o SD Card automaticamente."
fi

echo "========================================"

