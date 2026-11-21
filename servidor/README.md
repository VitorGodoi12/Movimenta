# Servidor do Stokio

O Python 3.10 ou superior executa a API com SQLite e sem bibliotecas externas. Execute a partir desta pasta:

```sh
python stokio.py
python -m unittest
```

O servidor ouve por padrão em `127.0.0.1:8765`. Configure `STOKIO_DATA` para guardar permanentemente os arquivos SQLite. A API de estoque fica em `lojas.sqlite` e o catálogo fica em `catalogo.sqlite`. Configure backups do diretório persistente e mantenha-o privado.

Para uso entre celulares, publique a API atrás de um proxy HTTPS e informe essa URL em Loja compartilhada no app. Se quiser distribuir o APK com o endereço preenchido, compile com `--dart-define=STOKIO_API_URL=https://estoque.exemplo.com`. Para testar pelo emulador Android, use um build de depuração e informe `http://10.0.2.2:8765`. No Flutter Web, configure `STOKIO_WEB_ORIGINS` com as origens autorizadas, separadas por vírgula.

## Publicar com HTTPS

Em um servidor Linux com Docker Compose, aponte o DNS do domínio para o IP do servidor e permita conexões externas nas portas 80 e 443. Na pasta servidor, copie .env.example para .env e informe apenas o hostname em STOKIO_DOMINIO, sem o prefixo https://. Mantenha o arquivo .env privado.

    docker compose config -q
    docker compose up -d --build
    curl --fail https://estoque.exemplo.com/health

Substitua estoque.exemplo.com pelo seu domínio. O Caddy emite e renova o certificado e redireciona HTTP para HTTPS. Só o Caddy publica portas na rede. Os volumes preservam o SQLite e os certificados ao recriar os contêineres. Configure uma cópia externa do banco antes de usar dados reais.

Use o endereço HTTPS em Loja compartilhada no APK existente. O certificado de produção depende de DNS e das portas públicas acessíveis.

## E-mail de solicitação

Configure `STOKIO_SMTP_HOST`, `STOKIO_SMTP_PORT` (padrão 587), `STOKIO_EMAIL_FROM` e, se exigido pelo provedor, `STOKIO_SMTP_USER` e `STOKIO_SMTP_PASSWORD`. O servidor usa STARTTLS. A solicitação fica disponível em Equipe mesmo se o serviço de e-mail estiver indisponível, e o aplicativo informa se o envio foi confirmado.

## Acessos

- O dono cadastra o mercado e pode copiar seu código em Equipe. Compartilhe-o só com quem precisa de acesso. O código dá entrada como funcionário.
- Funcionários consultam quantidade, corredor e validade. O acesso por e-mail entra em uma fila de aprovação.
- Gerentes e donos podem manter os produtos, atribuir responsáveis por corredor e revisar solicitações. Só donos podem atribuir ou alterar o cargo de dono. O dono fundador é protegido.
- Use Copiar estoque local para trazer cadastros existentes. A cópia leva saldo, nome, categoria, GTIN e a validade mais próxima. Lotes individuais, vendas, preços e histórico continuam no modo local.

## Catálogo

O arquivo `catalogo_inicial.json` contém 15 GTINs de produtos comuns consultados no [Open Food Facts](https://world.openfoodfacts.org/). Os dados do catálogo e seu cache separado são fornecidos sob a [ODbL](https://opendatacommons.org/licenses/odbl/1-0/). O catálogo oferece sugestões, que podem ser revisadas antes de cadastrar um produto na loja. O atendimento de outros GTINs depende da cobertura da base aberta.

Para adicionar mais dados ao cache a partir de códigos reais, use `python precarregar.py` seguido dos GTINs conferidos nas embalagens.
