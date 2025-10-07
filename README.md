# Filtragem e Conversão de Glebas - Crédito Rural SICOR

Este projeto é uma ferramenta desenvolvida para auxiliar na identificação e visualização de propriedades vinculadas a programas de crédito rural disponibilizados pelo SICOR (Sistema de Operações de Crédito Rural) do Banco Central do Brasil. A aplicação possibilita a filtragem de glebas de propriedades rurais a partir de arquivos no formato WKT e a conversão desses dados em arquivos KML para fácil visualização no Google Earth.

A principal motivação é permitir que produtores, pesquisadores e gestores possam entender de maneira visual as áreas que estão recebendo crédito rural, facilitando a análise territorial e estratégica das operações.

## Funcionalidades

- **Filtragem de Glebas**: Filtre registros de glebas a partir de um ponto central (extraído de uma URL do Google Earth) e um raio fornecido pelo usuário, criando um arquivo CSV com as glebas dentro dessa área.
- **Geração de Arquivos KML**: Gere arquivos KML individuais para cada polígono filtrado ou um único arquivo KML contendo todos os polígonos. É possível definir a cor e opacidade das áreas destacadas.
- **Interface Gráfica (Tkinter)**: A aplicação fornece uma interface intuitiva para facilitar a entrada de dados e configuração dos parâmetros necessários.

## Contexto do Projeto

Os dados de glebas são disponibilizados pelo SICOR, como parte dos microdados de Crédito Rural Público do Banco Central do Brasil. Estes microdados contêm informações detalhadas sobre operações de crédito rural registradas no sistema, incluindo geolocalização das propriedades beneficiadas.

A partir dessas informações, a aplicação possibilita:

- Filtrar propriedades que estão sendo beneficiadas por programas de crédito rural.
- Visualizar e analisar espacialmente as áreas que recebem o financiamento, facilitando a criação de relatórios, mapas e o entendimento da distribuição dos recursos.

Os dados podem ser encontrados na seção "[Sicor - Microdados do Crédito Rural Público](https://www.bcb.gov.br/estabilidadefinanceira/tabelas-credito-rural-proagro)".

## Estrutura do Projeto

- **input/**: Diretório para armazenar arquivos CSV de entrada (os arquivos WKT baixados).
- **filtered/**: Diretório para salvar os arquivos CSV filtrados, contendo apenas registros que estão dentro do raio especificado.
- **kml/**: Diretório para armazenar arquivos KML gerados.

## Requisitos

- **Python**: 3.6 ou superior
- **Bibliotecas Python**:
  - `shapely`: Manipulação de dados geométricos.
  - `tkinter`: Interface gráfica.
  - `tkcolorpicker`: Seletor de cores.
  - `pyproj`: Transformação de coordenadas.

Instale as dependências com o seguinte comando:

```bash
pip install shapely tkcolorpicker pyproj
```

## Como Usar

1. **Filtrar Glebas**:

   - Abra a aplicação.
   - Forneça a URL do Google Earth, o raio em metros e o ano do arquivo WKT desejado.
   - Clique no botão "Filtrar" e escolha onde salvar o arquivo CSV com os resultados filtrados.

2. **Gerar Arquivos KML**:
   - Selecione o arquivo CSV filtrado que deseja usar.
   - Escolha a cor para destacar as áreas (opcional).
   - Escolha o diretório onde deseja salvar os arquivos KML.
   - Clique em "Gerar KML" para gerar arquivos KML individuais ou em "Gerar KML Combinado" para criar um único arquivo com todos os polígonos.

## Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues e pull requests para melhorias ou correções.

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).
