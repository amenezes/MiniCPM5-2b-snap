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

## Variantes de quantização

Há três níveis de quantização disponíveis. O Q4_K_M é o padrão; troque com
`sudo minicpm5-2b use-model <variante>` e reinicie o serviço:

| Variante | Pesos do modelo | Disco (instalado) | Observações |
| --- | --- | --- | --- |
| `minicpm5-2b` (Q4_K_M) | 1,5 GB | ~1,7 GB | Melhor relação tamanho/qualidade, recomendado |
| `minicpm5-2b-q5km` (Q5_K_M) | 1,8 GB | ~2,0 GB | Melhor qualidade em raciocínio e chamada de ferramentas |
| `minicpm5-2b-q6k` (Q6_K) | 2,0 GB | ~2,2 GB | Qualidade próxima de FP16 para cargas sensíveis à precisão |

```shell
sudo minicpm5-2b use-model minicpm5-2b-q5km
sudo snap restart minicpm5-2b
```

## Decodificação especulativa com DSpark (opcional)

A variante `minicpm5-2b-dspark` combina os pesos Q4_K_M com o modelo draft
[MiniCPM5-2B-DSpark](https://huggingface.co/openbmb/MiniCPM5-2B-DSpark), da OpenBMB. O draft
propõe blocos de até 7 tokens e o modelo alvo os verifica, então a resposta continua sendo a do
modelo alvo -- a especulação só muda a velocidade (um token em empate quase exato ainda pode
diferir, porque o batching altera o arredondamento de ponto flutuante). O draft é um componente
separado: apenas essa variante o baixa (~650 MB).

```shell
sudo minicpm5-2b use-model minicpm5-2b-dspark
sudo minicpm5-2b use-model minicpm5-2b   # volta à variante padrão
```

Medido em um AMD Ryzen 9 3900X (motor cpu, Q4_K_M, contexto de 8K, draft BF16 do upstream):
geração de código em modo greedy passa de ~18,9 para ~31,6-37,4 tokens/s (~1,7-2,0x); chat com
temperatura 1.0 e raciocínio fica praticamente neutro (~17,3 para ~15,4-17,1 tokens/s). O ganho se
concentra em geração de baixa temperatura (código, extração): com amostragem o draft aceita menos
tokens e o custo dele consome quase toda a economia. Tool calling não muda.

O custo é ~650 MB de disco e ~0,8 GB de memória (pico de ~3,7 GB em 8K, contra ~2,9 GB da
variante padrão); abaixo de ~4 GB de RAM, use a variante padrão.

> [!NOTE]
> O `--fit` não contabiliza o draft ao dimensionar o contexto (o llama.cpp registra
> `[spec] failed to measure draft model memory`), então a variante DSpark deixa ~0,8 GB menos de
> folga do que o contexto dimensionado pressupõe. Em máquina com memória apertada (RAM ou VRAM),
> reduza o `min-context-size`.

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

🐛 **[Issues](https://github.com/amenezes/MiniCPM5-2b-snap/issues)**, relate problemas e solicite novos recursos

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
git clone https://github.com/amenezes/MiniCPM5-2b-snap
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

O `make init` baixa o GGUF Q4_K_M padrão (~1,5 GB) e verifica o seu sha256. Para baixar
todas as variantes (Q4_K_M, Q5_K_M, Q6_K e o draft do DSpark), use `make init-all`;
`make init-dspark` baixa apenas os pesos padrão e o draft. O draft é opcional no build,
como os pesos Q5_K_M/Q6_K: um snap sem ele não inclui o componente DSpark, então os builds
de publicação usam `make init-dspark`. Para usar uma cópia local, coloque-a em
`components/model-q4-k-m-gguf/MiniCPM5-2B-Q4_K_M.gguf` (e da mesma forma para as outras
variantes, incluindo `components/model-dspark-gguf/MiniCPM5-2.6B-DSpark.gguf`) e execute
`make verify-model` (ou `make verify-extra-models`, `make verify-dspark`). Com o snap
instalado, `make use-dspark` e `make use-default` alternam entre as variantes.
