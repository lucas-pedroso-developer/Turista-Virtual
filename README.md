# Turista-Virtual
Aplicativo para o curso da Udacity

Turista Virtual é um aplicativo que você pode fixar um "alfinete" em um qualquer ponto de um mapa, dependendo do ponto, 
pode haver fotos, essas fotos são salvas no banco de dados do celular, você pode escolher uma nova coleção, assim, as fotos 
serão trocadas por outras fotos da mesma região.

A primeira tela será o mapa
![img](https://user-images.githubusercontent.com/6620203/53884926-5bbd8900-3ffb-11e9-89ad-edeb819ca1d9.png)

Segure no ponto desejado no mapa, um "alfinete" é colocado nesse ponto
![img](https://user-images.githubusercontent.com/6620203/53884927-5bbd8900-3ffb-11e9-8426-f58e0aab3918.png)

Caso quiser excluir algum "alfinete", cique em editar no canto superior direito, após isso é só clicar no "alfinete" desejado, depois de excluído, é só 
clicar em Concluir no canto superior direito
![img](https://user-images.githubusercontent.com/6620203/53884929-5bbd8900-3ffb-11e9-83ca-200023e35d30.png)

Aperte em qualquer "alfinete", você irá para a tela das fotos que existe nesse ponto escolhido, pode ser que não exista nenhuma foto
![img](https://user-images.githubusercontent.com/6620203/53884931-5c561f80-3ffb-11e9-8432-ee46731c65e5.png)

Você pode deletar as fotos clicando nelas
![img](https://user-images.githubusercontent.com/6620203/53884932-5c561f80-3ffb-11e9-8df8-a399a76e55c0.png)

Se escolher Nova Coleção, as fotos serão trocadas por outras fotos da mesma região
![img](https://user-images.githubusercontent.com/6620203/53884933-5c561f80-3ffb-11e9-9d2f-558eb5660c3a.png)

Implementação

O aplicativo é composto por duas View Controllers, a ViewController e a PhotoViewController. Na ViewController, está a lógica 
do mapa, quando o usuário segura no mapa, é ativado a função pega o "LongPress" e já adiciona no core data a latitude e 
longitude do ponto escolhido, quando o usuário aperta em um "alfinete", é feito uma requisição para o flickr enviando a latitude 
e longitude, todas as fotos são salvas no core data, quando clica em nova coleção, todas as fotos são excluídas do core data e
é feito uma requisição para o clickr, assim, salvando novamente no core data as novas fotos.

Compilação

Na classe Constants, vá até a struct FlickrParameterValues e altere a propriedade APIKey com sua própria chave criada pelo flickr,
acesse https://www.flickr.com/services/developer para saber como criar essa chave.

Requisitos

Xcode 10
Swift 4.2

