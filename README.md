# OlhosCapolei
OlhosCapolei - Frightened Boy

Once there was a little boy.
He lived in a place where bad things happened.
He was afraid that he would be brutally killed,
Just like all the other little children had been.
And then, one day, along came a crab.
The boy tried to ignore the crab,
But it just stayed behind him.
Singing..

<h>
<h3>Para compilar, usar o CC65</h3>
$ apt-get install cc65<br>
$ ./buildCapolei.sh<p>
ou os comandos separados:<br>
$ cmake -S . -B build<br>
$ cmake --build build -t clean<br>
$ cmake --build build<br>
<hr>

<h3>Para gerar os sprites, usar o yychr</h3>
Não tem para Ubuntu. Tem que usar wine<p>
Baixar em qualquer site, como o [https://www.smwcentral.net/?p=section&a=details&id=27208] <p>
$ sudo apt update && sudo apt install wine -y<br>
$ wine yychr.exe<p>
<i>Às vezes, programas de Windows rodando no Wine precisam das fontes padrão da Microsoft para exibir os menus corretamente. Se notar que o YY-CHR abriu com textos invisíveis ou quadrados no lugar das letras, instale este pacote complementar no seu terminal:</i><br>
$ sudo apt install ttf-mscorefonts-installer -y<br>
<hr>
<h3>Para gerar a paleta</h3>
Tivemos dificuldades com a paleta gerada pelo yychr. Se isso acontecer, usar o python na pasta assets/img<p>
Gerar paleta na raça:<br>
$ python3 gera.py<p>
Converter a paleta gerada pelo yychr:<br>
$ python3 convertey.py<p>
<hr>





