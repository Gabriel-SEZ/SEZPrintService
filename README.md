# SEZ Print Service 0.4.0

Serviço Windows local para impressão automática e silenciosa de documentos do Smart EZ ERP, sem o diálogo de impressão do navegador.

## Recursos
- API HTTP local restrita a 127.0.0.1:32177.
- GET /api/status entrega versão, token temporário de pareamento e capacidades.
- GET /api/printers lista as filas de impressão do Windows.
- POST /api/print recebe HTML real, converte para PDF em navegador headless e imprime em silêncio.
- POST /api/test imprime uma página de teste A4 ou 80mm.
- Fila sequencial, limite de conteúdo, validação do token e allowlist CORS.
- Serviço Windows automático, supervisionado pelo host C#.

## Formatos
- A4: página A4 com estilos de impressão preservados.
- 80mm: largura térmica de 76mm e altura da página calculada a partir do conteúdo para reduzir cortes e páginas sobrando.

O mecanismo utiliza Edge ou Chrome instalado em nível de máquina para renderização e SumatraPDF portátil para envio silencioso ao spooler. O instalador baixa Node.js LTS e SumatraPDF diretamente das fontes oficiais durante a instalação.

## Instalação
Execute SEZ-Print-Service-Setup.exe como administrador. Depois, no ERP, abra Configurações > SEZ Print Service, conecte o serviço, selecione as impressoras e use os testes A4/80mm.

A opção Impressão automática silenciosa pode ser desligada no ERP; quando desligada, o navegador volta ao fluxo de impressão convencional.

## Requisitos e observações
- Windows 10/11 x64.
- Conexão à internet na primeira instalação.
- Edge ou Chrome instalado para todos os usuários.
- Impressoras e drivers instalados em nível de computador: o serviço executa como LocalSystem.
- A confirmação da API significa que o trabalho foi aceito pelo spooler, não que um sensor confirmou a saída física do papel.
- Não exponha a porta 32177 à rede.

## Build
O GitHub Actions compila o host C# no Windows runner e o instalador Inno Setup. O workflow executa os testes Node.js antes de empacotar.
