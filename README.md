# SEZ Print Service 0.4.7

Serviço Windows local para impressão automática e silenciosa de documentos do Smart EZ ERP, sem o diálogo de impressão do navegador.

## Recursos
- API HTTP local restrita a 127.0.0.1:32177.
- GET /api/status entrega versão, token temporário de pareamento e capacidades.
- GET /api/printers lista as filas de impressão do Windows.
- POST /api/print recebe HTML real, converte para PDF em navegador headless e imprime em silêncio.
- POST /api/test imprime uma página de teste A4 ou 80mm.
- Fila sequencial, limite de conteúdo, validação do token e allowlist CORS.
- Serviço Windows automático, supervisionado pelo host C#.
- Atualização interrompe o serviço anterior antes de substituir o executável em uso.
- O Setup cria `service-install.log` diretamente no Inno Setup, antes de iniciar o PowerShell. O log registra caminho e existência do script, comando executado, falha de inicialização do PowerShell e código de saída.

## Runtime incluído
O instalador inclui Node.js 22.23.3 x64 e SumatraPDF 3.6.1 portáteis, obtidos das fontes oficiais e verificados por SHA-256 durante o build. A instalação no computador não baixa nem extrai esses componentes. O host Windows executa o Node empacotado em `runtime\node.exe`; o motor de impressão usa `tools\SumatraPDF.exe`.

## Formatos
- A4: página A4 com estilos de impressão preservados.
- 80mm: largura térmica de 76mm e altura da página calculada a partir do conteúdo para reduzir cortes e páginas sobrando.

## Instalação e atualização
Execute SEZ-Print-Service-Setup-0.4.7.exe como administrador. Antes de substituir os arquivos, o Setup cria `%ProgramData%\SmartEZ\SEZ Print Service\logs\upgrade-stop.log`, interrompe SEZPrintService e aguarda o processo host liberar SEZPrintServiceHost.exe. Depois, instala os arquivos e registra/inicia novamente o serviço.

## Diagnóstico
- Parada para atualização: `%ProgramData%\SmartEZ\SEZ Print Service\logs\upgrade-stop.log`.
- Registro do serviço: `%ProgramData%\SmartEZ\SEZ Print Service\logs\service-install.log`. Este arquivo é criado pelo próprio Setup antes de executar o PowerShell.
- Execução do serviço: `%ProgramData%\SmartEZ\SEZ Print Service\logs\AAAA-MM-DD.log`.

O log de instalação inclui validação dos arquivos, execução do Node, criação do serviço, configuração de recuperação, tentativa de inicialização e eventos recentes do Service Control Manager caso o serviço não inicie.

## Requisitos e observações
- Windows 10/11 x64.
- Edge ou Chrome instalado em nível de máquina para renderização HTML.
- Impressoras e drivers instalados em nível de computador: o serviço executa como LocalSystem.
- A confirmação da API significa que o trabalho foi aceito pelo spooler, não que um sensor confirmou a saída física do papel.
- Não exponha a porta 32177 à rede.
- Não requer Node.js global nem downloads de runtime durante a instalação.
