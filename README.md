# SEZ Print Service — projeto para compilar o instalador

Este repositório contém o projeto do serviço local de impressão e o workflow para
compilar o instalador Windows `.exe` automaticamente no GitHub Actions.

## Compatibilidade-alvo
- Windows 10 64 bits
- Windows 11 64 bits

## Gerar o EXE pelo GitHub Actions

1. Crie um repositório no GitHub chamado `sez-print-service`.
2. Extraia todos os arquivos deste ZIP e envie-os para a raiz do repositório.
3. No GitHub, abra **Actions**.
4. Se necessário, habilite workflows para o repositório.
5. Execute **Build SEZ Print Service installer** em **Run workflow**.
6. Aguarde a execução terminar com sucesso.
7. Abra a execução concluída e baixe o artefato
   `SEZ-Print-Service-Setup-Windows-x64`.
8. Dentro do artefato estará `SEZ-Print-Service-Setup.exe`.

Também haverá compilação automática quando houver push na branch `main` com alterações
nos arquivos do serviço ou do instalador.

## Compilar localmente no Windows

1. Instale Inno Setup 6.
2. Abra `setup.iss` no Inno Setup Compiler.
3. Clique em Compile.
4. O executável será criado em `dist/SEZ-Print-Service-Setup.exe`.

## O que o instalador faz nesta versão
- Instala os arquivos do serviço.
- Se não encontrar Node.js, baixa e instala Node.js 22.23.4 x64 do site oficial.
- Cria atalhos no menu Iniciar e na pasta Inicializar.
- Inicia o serviço em segundo plano.

## Testar no ERP
1. Instale o EXE em Windows 10/11 64 bits.
2. Abra o ERP em `https://smartez.com.br`.
3. Acesse Configurações > Impressão.
4. Clique em Conectar serviço e depois Atualizar impressoras.
5. Selecione as impressoras padrão e teste.

## Limitações desta versão
Esta é uma versão inicial de integração. O serviço lista impressoras Windows e envia
um teste textual. A impressão real de documentos HTML/PDF, contratos, DANFE, recibos
e OS ainda precisa ser integrada nos respectivos fluxos do ERP e testada com as
impressoras físicas. O instalador gerado pelo workflow não é assinado digitalmente.
A primeira instalação pode exigir internet para baixar Node.js.

## Segurança
- O serviço escuta apenas em `127.0.0.1`.
- O endpoint local aplica CORS aos domínios Smart EZ e localhost.
- Não exponha a porta 32177 para a rede.
- O serviço não deve ser usado como serviço multiusuário/rede nesta versão.
