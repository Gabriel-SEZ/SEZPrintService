# SEZ Print Service 0.3.0

Projeto de instalador Windows para instalar o SEZ Print Service como **serviço nativo do Windows**, com inicialização automática antes do login.

## O que mudou
- Substitui o VBS/pasta Inicializar por serviço Windows `SEZPrintService`.
- `Start= auto`, conta `LocalSystem`.
- Processo Node.js oculto, supervisionado e reiniciado se encerrar.
- Recuperação do próprio Service Control Manager após falhas.
- Gerenciamento pelo `services.msc`.
- Logs em `%ProgramData%\SmartEZ\SEZ Print Service\logs`.
- Desinstalação para e remove o serviço.

## Build
O GitHub Actions compila o host C# e o instalador Inno Setup. Execute o workflow `Build SEZ Print Service installer` e baixe `SEZ-Print-Service-Setup-Windows-x64`.

## Observação
Como roda como `LocalSystem` antes do login, instale impressoras e drivers para todos os usuários/computador. Filas criadas apenas no perfil pessoal podem não estar visíveis ao serviço.

Consulte `LEIA-ME.txt` para instalação e limitações.
