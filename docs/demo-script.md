# Roteiro do vídeo de demonstração (8 min 30 s)

Use a branch `avaliacao-versao-atualizada`, a região `us-east-2` e o perfil AWS `feedflow`. O roteiro usa a aplicação ativa na stack `feedflow-dev`. O monitoramento foi preparado no repositório e sua implantação está bloqueada pela política da conta.

| Tempo | O que mostrar |
| --- | --- |
| 0:00–1:00 | Diagrama do README. HTTP API → Lambda da API → DynamoDB. O Stream aciona a Lambda de alertas e o EventBridge Scheduler aciona a Lambda de relatórios. Ambas publicam no SNS. |
| 1:00–2:00 | CloudFormation em `UPDATE_COMPLETE`, três Lambdas e tabela com Streams e índice `byWeek`. |
| 2:00–4:00 | Execute os quatro testes HTTP abaixo. Mostre 200/UP, 201/CRITICA, 201/BAIXA e 400. Abra o log de notificações com `publicados=1` e mostre o e-mail de alerta se estiver na caixa de entrada. |
| 4:00–5:00 | Consulte no DynamoDB os dois IDs das respostas. Mostre nota e urgência. |
| 5:00–6:30 | Invoque a Lambda do relatório, confira os logs e mostre o e-mail se recebido. A execução de 16/11/2026 publicou o relatório da semana de 09 a 15/11/2026 com zero avaliações. |
| 6:30–7:30 | Mostre os logs no CloudWatch. Abra `monitoring.yaml` e aponte os sete alarmes, o dashboard e o tópico operacional previstos. Mostre a restrição do CloudFormation registrada no README. |
| 7:30–8:30 | Mostre o repositório público e a execução de CI da branch. Abra o workflow de deploy direto e informe o estado do PR e do OIDC conforme a evidência disponível na gravação. |

## Comandos em ordem (Git Bash)

```bash
export AWS_PROFILE=feedflow AWS_REGION=us-east-2 AWS_PAGER=
out() {
  aws cloudformation describe-stacks --stack-name feedflow-dev \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" --output text
}
url=$(out ApiUrl)
url=${url%/}

curl -sS -i "$url/health"
curl -sS -i "$url/avaliacao" -H 'Content-Type: application/json' \
  -d '{"descricao":"Aula confusa","nota":2}'
curl -sS -i "$url/avaliacao" -H 'Content-Type: application/json' \
  -d '{"descricao":"Boa aula","nota":9}'
curl -sS -i "$url/avaliacao" -H 'Content-Type: application/json' \
  -d '{"descricao":"Teste de nota inválida","nota":11}'

read -r -p 'ID da avaliação crítica: ' critical_id
read -r -p 'ID da avaliação normal: ' normal_id
for id in "$critical_id" "$normal_id"; do
  aws dynamodb get-item --table-name "$(out FeedbackTable)" --consistent-read \
    --key "{\"id\":{\"S\":\"$id\"}}"
done
aws logs tail "$(out NotificationsLogGroup)" --since 10m

report_output=$(mktemp)
aws lambda invoke --function-name "$(out ReportsFunctionName)" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"source":"feedflow.scheduler.weekly-report"}' "$report_output"
cat "$report_output"
aws logs tail "$(out ReportsLogGroup)" --since 10m
```

A invocação retorna metadados à parte do corpo `null`. Confira a ausência de `FunctionError` e a linha do log com a semana e o total. Os logs comprovam publicação no SNS. Para comprovar recebimento, capture a caixa de entrada e oculte endereços e dados da conta. Se o tópico operacional for implantado, confira o status da assinatura SNS e abra o e-mail de confirmação, se necessário.

## Limpeza após a entrega

Execute somente após encerrar a entrega e se a stack de monitoramento tiver sido criada.

```bash
aws cloudformation delete-stack --stack-name feedflow-dev-monitoring --profile feedflow --region us-east-2
aws cloudformation wait stack-delete-complete --stack-name feedflow-dev-monitoring --profile feedflow --region us-east-2
```