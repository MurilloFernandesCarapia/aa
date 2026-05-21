# PetCare 360 — Containerização em Nuvem

Esse repositório é a **entrega da disciplina de DevOps Tools & Cloud Computing** (1º Sprint do Challenge 2026). A ideia da entrega é pegar uma API que já existe — a do nosso projeto PetCare 360 (Challenge FIAP/CLYVO VET) — e colocar ela pra rodar em nuvem, dentro de containers Docker, com banco também conteinerizado.

A API em si foi desenvolvida na disciplina de **Advanced Business Development with .NET**. Aqui o foco é outro: provar que conseguimos tirar a aplicação do "rodando no meu PC" e colocar ela em uma máquina virtual Azure, isolada em containers, com persistência de dados, sem nada amarrado no localhost.

> 📺 **Vídeo da entrega no YouTube:** [SUBSTITUIR_PELO_LINK_DO_VIDEO]
> 🌐 **API rodando em nuvem (durante a banca):** `http://4.168.192.201:8080/swagger`

---

## Sumário

- [O projeto PetCare 360](#o-projeto-petcare-360)
- [Benefícios para o negócio](#benefícios-para-o-negócio)
- [Arquitetura macro](#arquitetura-macro)
- [Como funciona por dentro](#como-funciona-por-dentro)
- [Rotas da API](#rotas-da-api)
- [Como rodar (How To)](#como-rodar-how-to)
  - [Opção 1 — Rodar localmente com Docker Compose](#opção-1--rodar-localmente-com-docker-compose)
  - [Opção 2 — Reproduzir nossa entrega em nuvem (Azure)](#opção-2--reproduzir-nossa-entrega-em-nuvem-azure)
- [Script Azure CLI](#script-azure-cli)
- [Dockerfile e Docker Compose](#dockerfile-e-docker-compose)
- [O grupo](#o-grupo)

---

## O projeto PetCare 360

O PetCare 360 nasceu de uma dor que qualquer dono de pet conhece: hoje a saúde do bicho vive aos pedaços. Tutor vai na clínica só quando o pet adoece, esquece quando foi a última vacina, perde a carteirinha, troca de clínica e o histórico fica perdido no caminho. Cada clínica tem o seu sistema, cada veterinário anota do seu jeito, e quem fica no prejuízo é o animal.

Nossa proposta é centralizar **tutor, pet, clínica, consultas, vacinas e medicamentos** em um lugar só. Essa API é o núcleo de cadastro de todo esse domínio — antes de qualquer informação chegar no aplicativo do tutor ou no painel da clínica, ela passa por aqui.

A API expõe **CRUD completo de 6 entidades** (Tutor, Pet, Clínica, Consulta, Vacina e Medicamento), além de rotas de consulta cruzada — tipo "me dá o histórico completo desse animal" ou "lista todas as vacinas que o Rex tomou".

## Benefícios para o negócio

A solução foi pensada pra atender três stakeholders ao mesmo tempo:

**Para o tutor:** acaba a história de carteirinha perdida e vacina vencida sem aviso. O histórico do pet fica num lugar só, acessível de qualquer lugar, mesmo que ele troque de clínica.

**Para a clínica veterinária:** quando o pet chega pra atendimento, o veterinário já tem o histórico inteiro na tela. Vacinas anteriores, medicações em curso, diagnósticos passados — tudo isso reduz drasticamente o tempo de anamnese e a chance de erro clínico (prescrever algo que conflita com medicação em uso, por exemplo).

**Para a CLYVO VET (cliente do Challenge):** abre a possibilidade de uma rede integrada de clínicas parceiras, com dados centralizados. Isso vira inteligência de mercado: dá pra entender padrões regionais de doença, sazonalidade de atendimentos, lacunas de cobertura vacinal — e a partir daí desenhar produtos e campanhas direcionadas.

**Para o time de DevOps (entrega desta disciplina):** ao colocar tudo em containers, o ambiente vira reprodutível. Qualquer pessoa do time clona o repo, roda **um comando** e tem a aplicação inteira de pé — mesma versão do .NET, mesma versão do Oracle, mesmo schema. Acaba o "na minha máquina funciona". E ao subir na Azure, deixamos de depender do servidor da faculdade pra ter o sistema no ar.

## Arquitetura macro

Para o desenho detalhado em alta resolução (feito no Draw.io), veja **[`docs/arquitetura.png`](docs/arquitetura.png)**. Aqui vai uma versão textual da mesma ideia:

```
┌──────────────────┐         HTTP/8080           ┌─────────────────────────────────────────┐
│                  │ ──────────────────────────▶ │       Azure VM (Ubuntu 24.04 LTS)       │
│  Cliente / App   │                             │           IP: 4.168.192.201             │
│  (Postman,       │                             │                                         │
│   navegador,     │ ◀────────────────────────── │  ┌───────────────────────────────────┐  │
│   Swagger UI)    │         JSON response       │  │     Docker Engine + Compose        │  │
│                  │                             │  │  ┌────────────────────────────┐   │  │
└──────────────────┘                             │  │  │  Container: petcare-api    │   │  │
                                                 │  │  │  ─────────────────────     │   │  │
                                                 │  │  │  ASP.NET Core 10           │   │  │
                                                 │  │  │  EF Core 10                │   │  │
                                                 │  │  │  Usuário: appuser (non-root)│   │  │
                                                 │  │  │  Porta: 8080               │   │  │
                                                 │  │  └────────────┬───────────────┘   │  │
                                                 │  │               │ TCP/1521          │  │
                                                 │  │               ▼ (rede interna)    │  │
                                                 │  │  ┌────────────────────────────┐   │  │
                                                 │  │  │ Container: petcare-oracle  │   │  │
                                                 │  │  │ ─────────────────────────  │   │  │
                                                 │  │  │ gvenzl/oracle-xe:21-slim   │   │  │
                                                 │  │  │ Schema: APP_USER           │   │  │
                                                 │  │  │ PDB: XEPDB1                │   │  │
                                                 │  │  │ Healthcheck habilitado     │   │  │
                                                 │  │  └────────────┬───────────────┘   │  │
                                                 │  │               │                   │  │
                                                 │  │               ▼                   │  │
                                                 │  │      ╔═══════════════════╗        │  │
                                                 │  │      ║  Volume nomeado:  ║        │  │
                                                 │  │      ║ petcare_oracle_data║       │  │
                                                 │  │      ║  (persistência)   ║        │  │
                                                 │  │      ╚═══════════════════╝        │  │
                                                 │  └───────────────────────────────────┘  │
                                                 │                                         │
                                                 │  Network Security Group:                │
                                                 │   ├─ Porta 22  (SSH)                    │
                                                 │   ├─ Porta 8080 (API/Swagger pública)   │
                                                 │   └─ Porta 1521 (Oracle, externo)       │
                                                 └─────────────────────────────────────────┘
```

## Como funciona por dentro

O fluxo de subida da aplicação (do `docker compose up` até a API atender uma requisição) acontece nessa ordem:

1. **Docker Compose** lê o `docker-compose.yml` e identifica dois serviços (`oracle-db` e `api`) mais um volume nomeado (`petcare_oracle_data`).
2. O container **`oracle-db`** sobe primeiro. Na primeira vez ele inicializa o Oracle XE 21c, cria o usuário `APP_USER` no PDB `XEPDB1` e roda um healthcheck a cada 30s pra avisar quando estiver pronto.
3. O container **`api`** só começa a subir quando o healthcheck do banco fica verde (`depends_on: condition: service_healthy`).
4. Quando a API sobe, o `Program.cs` tenta aplicar as **migrations do Entity Framework Core**. Como o Oracle às vezes demora pra responder mesmo após o healthcheck, há um **retry loop** de até 30 tentativas com 10s de intervalo entre elas.
5. Aplicadas as migrations, o `SeedData.cs` popula o banco com **12 registros iniciais** (2 tutores, 2 clínicas, 2 pets, 2 consultas, 2 vacinas, 2 medicamentos). Esse passo é idempotente — só roda se as tabelas estão vazias.
6. O Kestrel escuta na porta `8080` dentro do container, que é mapeada pra porta `8080` da VM Azure pelo Docker.
7. O Swagger fica disponível em `/swagger` independente do environment — assim o professor consegue testar tudo pelo IP público.

## Rotas da API

A documentação completa e interativa fica no **Swagger** em `/swagger` depois de subir a aplicação. Resumo das rotas (33 endpoints no total):

### Tutores — `/api/Tutores`
- `GET /api/Tutores` — lista todos
- `GET /api/Tutores/{id}` — busca por ID
- `POST /api/Tutores` — cria
- `PUT /api/Tutores/{id}` — atualiza
- `DELETE /api/Tutores/{id}` — remove

### Pets — `/api/Pets`
- `GET /api/Pets` — lista todos
- `GET /api/Pets/{id}` — busca por ID
- `GET /api/Pets/tutor/{tutorId}` — lista pets de um tutor
- `GET /api/Pets/especie/{especie}` — filtra por espécie
- `GET /api/Pets/{id}/historico` — pet + consultas + vacinas + medicamentos ⭐
- `POST /api/Pets` — cria
- `PUT /api/Pets/{id}` — atualiza
- `DELETE /api/Pets/{id}` — remove

### Clínicas — `/api/Clinicas`
- `GET /api/Clinicas` — lista todas
- `GET /api/Clinicas/{id}` — busca por ID
- `GET /api/Clinicas/cnpj/{cnpj}` — busca por CNPJ
- `POST /api/Clinicas` — cria
- `PUT /api/Clinicas/{id}` — atualiza
- `DELETE /api/Clinicas/{id}` — remove

### Consultas — `/api/Consultas`
- `GET /api/Consultas` — lista todas
- `GET /api/Consultas/{id}` — busca por ID
- `GET /api/Consultas/pet/{petId}` — consultas de um pet
- `GET /api/Consultas/clinica/{clinicaId}` — consultas de uma clínica
- `POST /api/Consultas`, `PUT`, `DELETE`

### Vacinas — `/api/Vacinas`
- `GET /api/Vacinas` — lista todas
- `GET /api/Vacinas/{id}` — busca por ID
- `GET /api/Vacinas/pet/{petId}` — vacinas de um pet
- `POST /api/Vacinas`, `PUT`, `DELETE`

### Medicamentos — `/api/Medicamentos`
- `GET /api/Medicamentos` — lista todos
- `GET /api/Medicamentos/{id}` — busca por ID
- `GET /api/Medicamentos/pet/{petId}` — medicamentos de um pet
- `POST /api/Medicamentos`, `PUT`, `DELETE`

### Relacionamento entre as entidades

```
TB_TUTOR (1) ─────┐
                  │ N
                  ▼
TB_PET (1) ──┬──→ TB_CONSULTA (N) ←── TB_CLINICA (1)
             │
             ├──→ TB_VACINA (N)
             │
             └──→ TB_MEDICAMENTO (N)
```

---

## Como rodar (How To)

Existem duas formas de pôr esse projeto pra rodar. A primeira é rodar local na sua máquina (útil pra desenvolvimento e teste). A segunda é reproduzir o que entregamos: a solução completa rodando em uma VM Azure provisionada via script.

### Opção 1 — Rodar localmente com Docker Compose

**Pré-requisitos:** Docker Desktop (Windows/Mac) ou Docker Engine + Compose plugin (Linux). Mais nada — não precisa de .NET SDK instalado, não precisa de Oracle instalado, é tudo conteinerizado.

**Passos:**

1. Clone o repositório:
   ```bash
   git clone https://github.com/MurilloFernandesCarapia/aa.git
   cd aa
   ```

2. Suba os containers:
   ```bash
   docker compose up -d
   ```

3. Acompanhe os logs (a primeira subida demora ~5 minutos por causa do download das imagens e da inicialização do Oracle):
   ```bash
   docker compose logs -f
   ```

   Quando aparecer `[startup] Banco pronto: migrations aplicadas e seed carregado.` nos logs da API, está tudo de pé. Pode dar `Ctrl+C` pra sair dos logs (o container continua rodando em background).

4. Abre o Swagger no navegador:
   ```
   http://localhost:8080/swagger
   ```

5. Pra derrubar tudo:
   ```bash
   docker compose down
   ```

   Se quiser apagar inclusive o volume com os dados do banco:
   ```bash
   docker compose down -v
   ```

### Opção 2 — Reproduzir nossa entrega em nuvem (Azure)

Esse é o caminho que usamos pra entrega. Provisiona uma VM Linux na Azure, instala o Docker, clona o repositório e sobe a aplicação. Pré-requisito: ter uma assinatura Azure ativa (qualquer uma — pessoal, Students, Pay-as-you-go).

**Passo 1: criar a VM e configurar a rede**

A criação foi feita pelo portal Azure com esses parâmetros:

| Parâmetro | Valor |
|---|---|
| Resource Group | `PetCare360_group` |
| VM Name | `PetCare360` |
| Region | Brazil South |
| Image | Ubuntu Server 24.04 LTS (Noble Numbat) — x64 Gen2 |
| Size | Standard_D2s_v3 (2 vCPU, 8 GB RAM) |
| Auth | Senha (username `rm564969`) |
| Inbound Ports abertas | 22 (SSH), 8080 (API), 1521 (Oracle) |

A versão equivalente em comandos `az` está em [`scripts/infra.sh`](scripts/infra.sh). Os mesmos resultados são alcançados pelo portal — basta criar a VM com a configuração acima e abrir as portas 8080 e 1521 nas regras de entrada do Network Security Group.

**Passo 2: conectar via SSH na VM**

No PowerShell (ou qualquer terminal com OpenSSH):

```bash
ssh rm564969@4.168.192.201
```

**Passo 3: instalar Docker + Git na VM**

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git nano curl ca-certificates gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

Sai da VM com `exit` e entra de novo (`ssh rm564969@4.168.192.201`) pra que o grupo `docker` faça efeito.

**Passo 4: clonar o repositório e subir a aplicação**

```bash
git clone https://github.com/MurilloFernandesCarapia/aa.git
cd aa
docker compose up -d
```

**Passo 5: acompanhar os logs até o banco ficar pronto**

```bash
docker compose logs -f api
```

Aguarde aparecer `[startup] Banco pronto: migrations aplicadas e seed carregado.` — quando aparecer, sua API está respondendo.

**Passo 6: acessar o Swagger**

No navegador (qualquer máquina, qualquer rede):
```
http://4.168.192.201:8080/swagger
```

**Passo 7: ao final da entrega, deletar tudo (obrigatório)**

```bash
az group delete --name PetCare360_group --yes --no-wait
```

Esse comando apaga a VM, o IP público, o disco, o NSG, a VNet — tudo de uma vez. Os créditos da assinatura param de ser consumidos imediatamente.

---

## Script Azure CLI

O script `scripts/infra.sh` automatiza tudo da Opção 2 acima (provisionamento da VM, abertura de portas, instalação de Docker, clone do repo e deploy). É executável pelo **Azure Cloud Shell** ou por qualquer máquina com Azure CLI instalado e autenticado.

Para executar:

```bash
az login
chmod +x scripts/infra.sh
./scripts/infra.sh
```

Ao final da execução o script imprime o IP público da VM e a URL completa do Swagger.

---

## Dockerfile e Docker Compose

O projeto traz dois arquivos centrais na raiz do repositório:

**[`Dockerfile`](Dockerfile)** — multi-stage build em duas etapas:
1. **Build stage** com `mcr.microsoft.com/dotnet/sdk:10.0` que faz `dotnet restore` e `dotnet publish` em modo Release.
2. **Runtime stage** com `mcr.microsoft.com/dotnet/aspnet:10.0` (imagem ~220MB) que cria um usuário **não-root** (`appuser`, UID 1000), copia os binários publicados e roda a aplicação.

A imagem final pesa ~250MB, expõe a porta 8080 e executa **sem privilégios de root** — atende a exigência do enunciado sobre rodar a aplicação como usuário sem privilégios administrativos.

**[`docker-compose.yml`](docker-compose.yml)** — orquestra os dois containers:
- `oracle-db` usa a imagem oficial `gvenzl/oracle-xe:21-slim`, com healthcheck e variáveis de ambiente que criam o schema `APP_USER` automaticamente.
- `api` faz build do Dockerfile local, espera o healthcheck do banco passar (`depends_on: condition: service_healthy`) e recebe a connection string via variável de ambiente — sem nada hardcoded no código.
- `volumes.oracle_data` — **volume nomeado** (`petcare_oracle_data`) que garante persistência dos dados do banco entre restarts dos containers. Mesmo se você der `docker compose down` e `up` de novo, os dados continuam lá.
- `networks.petcare-net` — rede bridge interna que permite à API resolver o banco pelo nome `oracle-db` em vez de IP.

---

## O grupo

| Nome | RM | Turma |
|---|---|---|
| Murillo Fernandes Carapia | RM564969 | 2TDSPW |
| Kauan Vieira de Lima | RM565403 | 2TDSPW |
| João Vitor Lacerda | RM565565 | 2TDSPW |

---

**FIAP · 2TDSPW · Challenge 2026 · 1º Sprint DevOps Tools & Cloud Computing**

*Em parceria com a CLYVO VET*
