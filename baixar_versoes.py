import os
import re
import html
import subprocess
from datetime import datetime

# Configurações de caminhos
FILE_PATH = "OlhosCapolei/build/OlhosCapolei.smc"
OUTPUT_DIR = "roms"       # Pasta onde os arquivos .smc serão salvos
HTML_FILE = "index.html"  # Caminho para o seu arquivo HTML

def run_cmd(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Erro ao executar comando: {' '.join(cmd)}")
        print(f"Detalhe:\n{result.stderr}")
        exit(1)
    return result.stdout.strip()

def main():
    print("Lendo histórico do Git...")
    log_format = "%H|%ct|%s"
    raw_logs = run_cmd(
        ["git", "log", f"--pretty=format:{log_format}", "--", FILE_PATH]
    )

    if not raw_logs:
        print(f"Nenhum commit encontrado para '{FILE_PATH}'.")
        return

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    commits_por_dia = {}

    for line in raw_logs.splitlines():
        parts = line.split("|", 2)
        if len(parts) < 3:
            continue
        commit_hash, timestamp_str, commit_msg = parts
        
        dt = datetime.fromtimestamp(int(timestamp_str))
        date_key = dt.strftime("%Y-%m-%d")

        if date_key not in commits_por_dia:
            commits_por_dia[date_key] = {
                "hash": commit_hash,
                "dt": dt,
                "msg": commit_msg
            }

    # Ordena cronologicamente para numerar corretamente (1 = mais antigo, N = mais recente)
    dias_ordenados = sorted(commits_por_dia.keys())
    linhas_tbody = []

    for idx, date_key in enumerate(dias_ordenados, start=1):
        info = commits_por_dia[date_key]
        c_hash = info["hash"]
        short_hash = c_hash[:7]
        dt = info["dt"]
        c_msg = html.escape(info["msg"])

        rom_filename = f"capolei{dt.strftime('%d%m%y%H%M')}.smc"
        data_formatada = dt.strftime("%d-%m-%Y %H:%M")
        thumb_name = f"thumb{idx}.png"

        # Salva o arquivo binário .smc na pasta roms/
        smc_out_path = os.path.join(OUTPUT_DIR, rom_filename)
        with open(smc_out_path, "wb") as f_smc:
            subprocess.run(
                ["git", "show", f"{c_hash}:{FILE_PATH}"],
                stdout=f_smc,
                check=True
            )

        bloco_tr = f"""        <!-- commit:{short_hash} -->
        <tr>
            <td>
                <img src="img/{thumb_name}" width="100px" height="100px" >
            </td>
            <td>
                {c_msg}
            </td>
            <td>
                {data_formatada}
            </td>
            
            <td>
                <a href="play.html?rom={rom_filename}">Play</a> 
            </td>
        </tr>"""
        linhas_tbody.append(bloco_tr)
        print(f"[{idx}] Salvo: {rom_filename} | {data_formatada} | {info['msg']}")

    # Inverte a lista para que o mais recente (maior número) fique no topo da tabela
    linhas_tbody.reverse()

    novo_tbody = "<tbody>\n" + "\n".join(linhas_tbody) + "\n        </tbody>"

    if not os.path.exists(HTML_FILE):
        print(f"Erro: Arquivo '{HTML_FILE}' não encontrado.")
        return

    with open(HTML_FILE, "r", encoding="utf-8") as f_html:
        conteudo_html = f_html.read()

    if "<tbody>" not in conteudo_html or "</tbody>" not in conteudo_html:
        print("Erro: Tags <tbody> e </tbody> não encontradas no HTML.")
        return

    conteudo_atualizado = re.sub(
        r"<tbody>.*?</tbody>",
        novo_tbody,
        conteudo_html,
        flags=re.DOTALL
    )

    with open(HTML_FILE, "w", encoding="utf-8") as f_html:
        f_html.write(conteudo_atualizado)

    print(f"\nSucesso! Arquivo '{HTML_FILE}' atualizado com o mais recente no topo.")

if __name__ == "__main__":
    main()

