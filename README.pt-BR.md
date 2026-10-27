# Snap de inferência do MiniCPM5 2B

[![minicpm5-2b](https://snapcraft.io/minicpm5-2b/badge.svg)](https://snapcraft.io/minicpm5-2b)

<!-- README-I18N:START -->

[English](./README.md) | **Português (Brasil)** | [简体中文](./README.zh-CN.md)

<!-- README-I18N:END -->

O **[MiniCPM5-2B](https://huggingface.co/openbmb/MiniCPM5-2B)** é o modelo denso de 2,5 B
parâmetros da [OpenBMB](https://huggingface.co/openbmb), ajustado por instrução e construído
para execução no próprio dispositivo e em ambientes com recursos limitados, com capacidades de
raciocínio e de chamada de ferramentas.

Use este snap para instalar rapidamente um ambiente otimizado para inferência local com o
MiniCPM5 2B.

O snap inclui os seguintes motores de inferência otimizados por hardware:

* cpu: otimizado para CPUs x64 e ARM (armv8, armv9)
* nvidia-gpu: aceleração por GPU com CUDA
* amd-gpu: aceleração por GPU com ROCm para GPUs AMD

O motor mais adequado é selecionado automaticamente de acordo com o hardware disponível.

#### Instalação
```shell
sudo snap install minicpm5-2b
```

#### Execução
```shell
minicpm5-2b
```

> [!TIP]
> Alguns aceleradores exigem [drivers](https://documentation.ubuntu.com/inference-snaps/how-to/setup/drivers/) adicionais para funcionar com este snap.
> O motor `amd-gpu` usa o driver `amdgpu` do kernel (KFD); as bibliotecas de user
> space do ROCm vêm embarcadas no snap, então não é preciso instalar ROCm no host.

## Requisitos

Medidos como o pico de RSS do processo `llama-server`, com os pesos Q4_K_M incluídos
(1,6 GB) e o runtime llama.cpp da versão fixada, no motor cpu:

| Tamanho de contexto | Pico de memória |
| --- | --- |
| 4 096 (piso definido por `--fit-ctx`) | ~2,6 GB |
| 32 768 | ~3,8 GB |
| 131 072 (máximo do modelo) | ~7,8 GB |

O uso de disco é de ~1,7 GB após a instalação (snap, componente do llama.cpp e pesos),
mais ~1,1 GB se o motor nvidia-gpu for selecionado, ou ~3,8 GB se o motor amd-gpu for
selecionado.

O tamanho do contexto não é fixo: o recurso `--fit` do llama.cpp o dimensiona conforme a
memória disponível, usando `--fit-ctx` (padrão 4096) como piso. Considere **~42 KB por
token** de contexto além de ~2,5 GB, e o runtime escolhe o maior contexto que couber.
Abaixo de ~2,5 GB o modelo não roda.

## Configuração

O motor lê as suas opções da configuração do snap:

| Opção | Padrão | Para que serve |
| --- | --- | --- |
| `min-context-size` | `4096` | Piso do `--fit-ctx`; o `--fit` amplia o contexto até o limite de 128K do modelo |
| `sleep-idle-seconds` | `600` | Tempo ocioso antes de o `llama-server` descarregar o modelo |
| `reasoning-preserve` | `true` | Mantém o traço de raciocínio no histórico completo (`false` economiza tokens) |
| `http.port` / `http.host` | `8354` / `127.0.0.1` | API compatível com OpenAI |
| `webui.http.port` / `webui.http.host` | `8355` / `127.0.0.1` | Web UI incluída no snap |

Leia com `minicpm5-2b get`; alterar exige root (`sudo minicpm5-2b set`), e o serviço precisa ser
reiniciado para aplicar:

```shell
minicpm5-2b get
sudo minicpm5-2b set reasoning-preserve=false
sudo snap restart minicpm5-2b
```

### Raciocínio por requisição

`reasoning-preserve` decide o que fica no *histórico*; se o modelo pensa antes de responder é uma
decisão de cada requisição. O MiniCPM5-2B é um modelo de raciocínio, então com o template padrão um
`max_tokens` pequeno pode ser consumido inteiro pelo traço de raciocínio: a resposta volta com
`content: ""` e `finish_reason: "length"`. Para pular o raciocínio:

```shell
curl -s http://127.0.0.1:8354/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "minicpm5-2b",
  "messages": [{"role": "user", "content": "Diga OK"}],
  "max_tokens": 256, "temperature": 1.0, "top_p": 0.95, "min_p": 0.0,
  "chat_template_kwargs": {"enable_thinking": false}}'
```

Com o raciocínio desligado a resposta vai direto em `message.content` e `reasoning_content` fica
vazio.

## Recursos

📚 **[Documentação](https://documentation.ubuntu.com/inference-snaps/)**, aprenda a usar snaps de inferência

🤗 **[Card do modelo](https://huggingface.co/openbmb/MiniCPM5-2B)**, documentação do modelo no upstream

📦 **[Pesos GGUF](https://huggingface.co/openbmb/MiniCPM5-2B-GGUF)**, os pesos quantizados que este snap inclui

🧩 **[Coleção MiniCPM5](https://huggingface.co/collections/openbmb/minicpm5)**, os outros tamanhos e formatos da família

💻 **[Código do MiniCPM](https://github.com/OpenBMB/MiniCPM)**, repositório upstream e guias de implantação

🐛 **[Issues](https://github.com/canonical/inference-snaps/issues)**, relate problemas e solicite novos recursos

## Notas sobre este snap

* **Versão fixada do runtime:** o llama.cpp está fixado no build `b10344`. O MiniCPM5-2B
  precisa do parser de chat e de chamada de ferramentas do MiniCPM5 do llama.cpp, que
  apareceu pela primeira vez no build `b10154`; o `b10344` é o build também usado pelos
  snaps `phi4`, `smollm2` e `gemma4`. As atualizações chegam como PRs revisados pelo
  Renovate (nunca com automerge) e precisam passar no smoke test de chamada de ferramentas.
* **Chamada de ferramentas:** depende do chat template embutido no GGUF, aplicado pelo
  `llama-server` (`--jinja`). O raciocínio é devolvido em `reasoning_content`. O modelo apenas
  *propõe* a chamada (`finish_reason: "tool_calls"`) e executá-la é papel do cliente — o snap não
  traz executor de ferramentas, então nada roda comandos na sua máquina em nome do modelo.
* **Traço de raciocínio:** o motor sempre passa `--reasoning-preserve` ou
  `--no-reasoning-preserve` de forma explícita, porque o padrão do llama.cpp mudou entre builds
  (`b10344`: desligado, `b11100`: ligado). A preservação vem ligada; defina
  `reasoning-preserve=false` para trocá-la por orçamento de tokens (ver
  [Configuração](#configuração)).
* **Amostragem:** o motor define `min_p=0.0`, conforme recomendado pelo card do modelo (o
  padrão `0.05` do llama.cpp leva a respostas repetitivas).
* **Licença do modelo:** Apache-2.0 (OpenBMB). O código de empacotamento é GPL-3.0.
* **Seleção de motor:** os motores `nvidia-gpu` e `amd-gpu` são escolhidos sempre que
  existe uma GPU do fornecedor correspondente no barramento PCI, mesmo que o driver não
  esteja utilizável. Nesse caso o backend falha ao inicializar e o llama.cpp cai para o
  backend de CPU; rode `sudo minicpm5-2b use-engine cpu` para voltar e liberar o
  componente do motor (~1,1 GB no NVIDIA, ~3,8 GB no AMD). O motor AMD só casa as
  microarquiteturas suportadas pelo build ROCm embarcado (gfx1010–gfx1201, incluindo a
  RX 9070 XT); GPUs AMD mais antigas selecionam o motor cpu. A seleção roda
  na instalação e precisa da interface `hardware-observe`; se a auto-conexão dela ainda não tiver
  sido concedida, conecte e rode a seleção manualmente:
  ```shell
  sudo snap connect minicpm5-2b:hardware-observe
  sudo minicpm5-2b use-engine --auto
  ```
* **O motor AMD precisa de `process-control`:** o runtime ROCm fixa suas threads de trabalho com
  `sched_setaffinity`, e a política seccomp padrão do snapd só permite essa chamada para o pid 0.
  Sem o plugue, o HSA falha ao inicializar, o llama.cpp registra `no ROCm-capable device is
  detected` e roda na CPU enquanto o motor continua aparecendo como `amd-gpu`. A interface não é
  auto-conectada, então conecte-a uma vez após a instalação:
  ```shell
  sudo snap connect minicpm5-2b:process-control
  sudo snap restart minicpm5-2b.server
  ```
* **Provider:** o snap exporta um slot de conteúdo `inference-provider`, para que outro snap
  consuma este endpoint em vez de rodar o próprio modelo.
* **API local:** o endpoint não tem autenticação e permite requisições cross-origin, o que a web
  UI incluída precisa. Ele escuta apenas em `127.0.0.1` — não reaponte `http.host` para uma
  interface pública.

## Compilar e instalar a partir do código-fonte

Clone o repositório:
```shell
git clone <this-repo>
```

Inicialize o ambiente de desenvolvimento:
```shell
make init
```

Por padrão o `snapcraft` compila dentro de um contêiner, então é preciso ter um provedor de build
disponível. Com LXD, inicialize-o uma vez (`--storage-backend=dir` evita um pool ZFS em loop):

```shell
lxd init --auto --storage-backend=dir
```

Sem provedor, compile no próprio host com
`sudo snapcraft pack --destructive-mode --platform amd64`.

Compile e instale o snap:
```shell
make build
make install
```

O `make init` baixa o GGUF da versão fixada (~1,5 GB) e verifica o seu sha256. Para usar
uma cópia local, coloque-a em `components/model-q4-k-m-gguf/MiniCPM5-2B-Q4_K_M.gguf` e
execute `make verify-model`.

## Publicação na Snap Store

Dois pedidos à loja são pré-requisitos, e ambos demoram, então abra-os cedo:

* **Permissão de upload de componentes** — os pesos e o runtime llama.cpp viajam como
  [componentes](https://snapcraft.io/docs/explanation/how-snaps-work/snap-components/), e o upload
  de componentes é restrito a contas na allow-list da loja. Peça no
  [fórum do Snapcraft](https://forum.snapcraft.io/c/store-requests/).
* **Auto-conexão de `hardware-observe`** — a interface não é auto-conectada por padrão, então uma
  instalação vinda da loja não detecta o hardware no `use-engine --auto` até o pedido ser
  aprovado (ver o
  [processo](https://snapcraft.io/docs/reference/administration/process-for-aliases-auto-connections-and-tracks/)).
* **Auto-conexão de `process-control`** — também não é auto-conectada, e o motor `amd-gpu` não
  inicializa o ROCm sem ela (ver a nota sobre AMD acima). Peça junto com `hardware-observe`.

O primeiro upload também exige o nome registrado e um repositório que exista de fato: a página da
loja aponta para `website`, `source-code`, `issues` e `contact` do `snap/snapcraft.yaml`.

```shell
snapcraft login
snapcraft register minicpm5-2b
make build
./dev/upload.sh latest/edge   # snapcraft upload <snap> --component ... --release=latest/edge
```

O `.github/workflows/cicd.yaml` publica em `latest/edge` a cada push na `main` quando o secret
`SNAPCRAFT_STORE_CREDENTIALS` (saída de `snapcraft export-login`) estiver configurado.
