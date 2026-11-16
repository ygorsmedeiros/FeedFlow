# Roteiro do vídeo de demonstração (7–10 min)

Pré-requisitos: stack `feedflow-dev` implantada, e-mails de assinatura confirmados, `$URL` = output `ApiUrl`.

1. **Arquitetura (1 min):** mostrar o diagrama do README e explicar o modelo serverless na AWS.
2. **Cloud configurada (2 min):** console AWS → CloudFormation (stack), 3 Lambdas, DynamoDB (tabela, GSI `byWeek`, Streams), SNS, SQS, EventBridge Scheduler (segunda 09:00), IAM (roles separadas, boundaries).
3. **Segurança (1 min):** policies mínimas, criptografia, OIDC (sem chaves no GitHub), throttling da API.
4. **Avaliação normal (1 min):**
   `curl -X POST $URL/avaliacao -H 'Content-Type: application/json' -d '{"nota":9,"descricao":"Ótima aula"}'` → 201; item no DynamoDB; **nenhum e-mail**.
5. **Avaliação crítica (1 min):**
   `curl -X POST $URL/avaliacao -H 'Content-Type: application/json' -d '{"nota":2,"descricao":"Áudio cortando"}'` → 201; mostrar o **e-mail de urgência** (descrição, urgência, data de envio) chegando.
6. **Erro de validação (30 s):** `{"nota":11}` → 400.
7. **Relatório semanal (1 min):** `aws lambda invoke --function-name feedflow-dev-reports --payload '{"source":"feedflow.scheduler.weekly-report"}' --cli-binary-format raw-in-base64-out out.json` → mostrar o e-mail com média, contagem por dia e por urgência.
8. **Monitoramento (1 min):** CloudWatch → dashboard `feedflow-dev-overview`, lista de alarmes, logs de uma Lambda.
9. **Deploy automatizado (1 min):** GitHub → Actions → workflow *Deploy (AWS SAM)* verde (testes, deploy, smoke test).
10. **Repositório (15 s):** mostrar que é público e o README.

Conferir antes de publicar: áudio, legibilidade da tela, duração aceita pela plataforma.
