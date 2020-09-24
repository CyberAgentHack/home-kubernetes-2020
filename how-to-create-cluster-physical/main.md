# Raspberry Piクラスタの組み方

## 写真でわかる組立手順

今回は3台のRaspberry Piを使用してKubernetesを構築しますが、基板がむき出しのまま扱うと故障の恐れがあり、また無思考に並べてしまうとどのRaspberry PiにSSHするのかも分からなくなるという事故が起きる可能性があります。

そのため、今回はRaspberry Piを縦に並べられるスタック型のRaspberry Piケースを用意しました。これを組み立てて最高のおうちKubernetesを目指しましょう。

完成図はこのような形になります。※写真はクリアモデルであり、皆さんにお渡ししているのはブラックモデルです

![完成図](./makeup-cluster/01_cluster.jpg)

早速組み立てていきましょう。

こちらが1段作るのに利用する材料です。

![材料](./makeup-cluster/02_component.jpg)

- A: Raspberry Pi4 本体
- B: Raspberry Pi PoE Hat
- ケースボックスから取り出す
    - C: 下に敷くプラスチック板 (底面用は真ん中に穴が空いていない物を利用してください)
    - D: 銀のナット 4個
    - E: 平ねじ 4個 (底面でのみ利用します)
    - F: 金の長いスペーサー 4個
    - G: ヒートシンク
- H: M2.5 ねじ 4個

合わせてケースからドライバーを取り出しておきましょう。今回の組立全般で利用します。

事前にプラスチック板から保護シートを剥がしておきましょう。

![保護シート剥がし前](./makeup-cluster/03_sheet-before.jpg)
![保護シート剥がし後](./makeup-cluster/04_sheet-after.jpg)

### PoE Hatの取り付け

B: Raspberry Pi PoE Hatの箱を開け、PoE Hat本体、付属のねじ4本、付属のスペーサー4本を取りだしましょう。
そして本体に空いているねじ穴に対して、上からねじを、下からスペーサーを使って挟み込みます。

![PoEHatにねじを取り付け](./makeup-cluster/03_poehat_1.jpg)

4箇所全てにねじ止めし裏返すとこのようになります。

![PoEHatにねじどめおわり](./makeup-cluster/04_poehat_2.jpg)

PoE Hatへのねじ止めがおわったら、PoE HatをRaspberry Pi本体に取り付けます。

A: Raspberry Pi本体を開封し取り出してみましょう。

G: ヒートシンクにある"For Pi 4B"と書かれた中から、最も大きいヒートシンクをRaspberry Pi4本体のCPUに貼りつけてください。

他の黒いチップに対してもヒートシンクも貼る事ができれば貼りましょう。
写真では"For Pi 3B+/3B"と書かれた銅色のヒートシンクが薄いため細長いチップに貼りつけています。

![rpi4本体](./makeup-cluster/05_rpi4.jpg)

無事にヒートシンクが貼りつけられたら、次はPoE Hatとの接続です。

Raspberry Pi4側にある20本のピンを、PoE Hatのスペーサーを取り付けた側にある同数の穴に差し込んでいきます。
このとき、垂直に力を入れるよう注意してください。製品によっては少し堅いかもしれませんが、垂直に力を入れていれば問題なく入ります。

![さす場所](./makeup-cluster/06_pin.jpg)

こちらの写真のように、PoE Hatに取り付けたスペーサーがRaspberry Pi本体の基板にあたるまで押し込んでください。

![rpi-plus-hat](./makeup-cluster/07_rpi-plus-hat.jpg)

これにてPoE Hatの取り付けは完了です。

### 底面プラスチック板の取り付け

Raspberry Piを固定するためにプラスチック板を取り付けます。
材料C, D, Hを用意してください。

底面のプラスチック板にある中央4箇所の穴にD: ナットを用いてH: M2.5ねじを固定します。
Raspberry Piを固定するための穴です。

![板とねじとナット](./makeup-cluster/08_port.jpg)

片方の面に指を使ってナットを穴の位置に固定させ、もう片方の面からねじをいれます。
手を離してもナットやねじが落ちないぐらいまでねじを回してください。

4箇所全て同じ方向にナットとねじを固定してください。

![板に固定](./makeup-cluster/09_4port.jpg)

ではRaspberry Piにプラスチック板を固定しましょう。
まずはRaspberry Pi本体を裏返し、プラスチック板がRaspberry Piのねじ穴と正しい位置に置けるのかを確かめましょう。

こちらの写真左側にあるRaspberry Pi本体のmicroSDカードスロットと、プラスチック板の切りかけが同じ方向である必要があることに注意してください。

![プラスチック板をRPiの上に置く](./makeup-cluster/10_board-on-board.jpg)

4箇所とも正しい位置にねじがあることを確認したら、ドライバーを使ってねじ止めしていきます。
このとき、ねじ止めは4箇所を少しずつ止めることを気をつけてください。
ねじ止めの基本として「全体を少しずつ進める」「次に止めるのは対角線上のねじ」であることを意識してください。これによりプラスチック板が歪むことを防ぐことができます。

## どんどん積み上げていく

無事にプラスチック板が取り付けることができたら、積み上げていくために長いスペーサーを取り付けます。
材料E, Fを用意してください。

底面プラスチック板の1番外側の4箇所にスペーサーを取り付けます。

![板とねじとスペーサー](./makeup-cluster/11_port-spacer.jpg)

底面側からE: 平ねじを指でおさえ、上面側からスペーサーを取り付けると良いでしょう。

![スペーサーの取り付け](./makeup-cluster/12_port-spacer2.jpg)

同様に4箇所にスペーサーを取り付けます。

![4箇所にスペーサー](./makeup-cluster/13_4spacer.jpg)

これにて1段目が完了です。

同じ要領でもう一段用意します。最底面でない場合穴の空いたプラスチック板を用いることに注意してください。

![もう1段用意](./makeup-cluster/14_3mincook.jpg)

2段目のプラスチック板における4箇所の穴を、1段目のスペーサに差し込みます。

![ドッキング](./makeup-cluster/15_docking.jpg)

1段目のスペーサのねじ部分を、2段目のスペーサで固定します。これを更に3段目まで進めましょう。

![更にドッキング](./makeup-cluster/16_3docking.jpg)

これで積み上げ完了です。

### 蓋の取り付け

最後に蓋を取り付けましょう。

蓋の材料はこちらです。全てケースボックスから取り出してください。

![蓋の材料](./makeup-cluster/17_cover-component.jpg)

- I: 蓋用プラスチック板
- J: 蓋用装飾品
- K: 銀のナット (Dと同じものです)
- L: 蓋用の留めねじ
- M: 銀のねじ

I: 二用プラスチック板とJ: 蓋用装飾品を上からL: 蓋用の留めねじ、下からK: 銀のナットを使って固定します。

![ねじを穴に入れる](./makeup-cluster/18_cover-port.jpg)

![固定する1](./makeup-cluster/19_cover-ported1.jpg)
![固定する2](./makeup-cluster/20_cover-ported2.jpg)

こちらも同様に4箇所で固定します。

![4箇所で固定](./makeup-cluster/21_4port.jpg)

最後は蓋を先ほど積み上げたRaspberry Piクラスタに載せ、M: 銀のねじで固定して完成です。

![蓋を載せてねじで固定する](./makeup-cluster/22_result.jpg)

最後に、全体を見てどこか歪んでいるところが無いのかを確認してください。
多少の歪みはありますが、大きく歪んでいる場合はねじを締め直すなどで対応してください。

![最終横から](./makeup-cluster/23_resultside.jpg)

### スイッチの取り付け

Raspberry Piクラスタは無事に組みあがりましたが、このままだと電源もネットワークも接続できていません。
今回は手のひらサイズに収まるように更にパーツを追加しましょう。

材料はこちらです。

![スイッチ材料](./makeup-cluster/24_component.jpg)

スイッチングハブから本体の他にゴム足を取りだしておいてください。

先に完成図を示します。

![スイッチ取り付け済み](./makeup-cluster/25_result.jpg)

先ほど組んだRaspberry Piクラスタの横にスイッチを配置し、下に土台としてアクリル板を設置します。

まず、両面テープを貼る位置を確認しましょう。アクリル板の上にRaspberryPiクラスタを置き、地面に当たる位置を確認してください。

![仮組み](./makeup-cluster/26_kari.jpg)

ちょうどRaspberry Piクラスタの底面にあるねじがあたる位置に両面テープを貼りつけます。

![両面テープを貼ったスイッチ](./makeup-cluster/27_tape.jpg)

合わせてスイッチの底面側にも両面テープを貼ります。Raspberry Pi側のLANポートとスイッチのLANポート側が同じになるように貼りつけてください。

![両面テープを底面にも貼ったスイッチ](./makeup-cluster/28_tape2.jpg)

両面テープを剥がして固定する前に、アクリル板に足を付けましょう。こちらも両面テープが既についているので、剥がして固定しましょう。

![アクリル板に足をつける](./makeup-cluster/29_foot.jpg)

いよいよ固定です。6枚の両面テープを剥がし写真のようにアクリル板の上にRaspberry Piクラスタとスイッチを固定しましょう。

![スイッチ取り付け済み](./makeup-cluster/25_result.jpg)

最後にLANケーブルを配線して完成です。

![配線済み](./makeup-cluster/30_cabled.jpg)

## SDカードにOSをインストールする

### この章で使う物

- microSDカード 3枚
- microSDカード リーダライター 1個

### 本文

Raspberry Piをクラスタとして扱うために、OSをインストールしましょう。
Raspberry PiのOSをインストールする場所として、今回は最もメジャーなmicroSDカードを用いる方式を取ります。

microSDカードをOS用途として用いるために、OS用のデータをコピーします。この作業はしばしば「SDカードに焼く」と呼ばれます。
以前はSDカードにコピーする汎用的なソフトウェアが利用されてきましたが、現在はRaspberry Pi向けのSDカードを作成するソフトウェアが公開されているため、これを用います。

[こちら](https://www.raspberrypi.org/downloads/)から、"Raspberry Pi Imager"をダウンロードしましょう。自分の利用しているOSに合わせて、"for Windows", "for macOS", "for Ubuntu"から選択してください。もしその他のOSを利用している場合は本ページの内容にしたがってSDカードにイメージファイルをコピーしても問題ありません。

![rpii-download.png](./burn-sd/rpii-download.png)

インストールするとこのような画面が出るようになります。

![rpii-boot.png](./burn-sd/rpii-boot.png)

"CHOOSE OS"を選ぶと、どのOSをインストールするか選択することができます。今回はUbuntu20.04を利用するため、"Ubuntu"→"Ubuntu 20.04.1 LTS (Raspberry Pi 3/4)"を選択します。

![rpii-chooseos.png](./burn-sd/rpii-chooseos.png)

![rpii-chooseos-detail.png](./burn-sd/rpii-chooseos-detail.png)

このタイミングで、用意しておいたmicroSDカードをPCに接続しましょう。リーダライターを経由して挿入した上で"SD Card"をクリックすると、31GBのmicroSDが表示されるので、こちらを選択しましょう。

![rpii-choosesd.png](./burn-sd/rpii-choosesd.png)

![rpii-choosesd-detail.png](./burn-sd/rpii-choosesd-detail.png)

OSとmicroSDカードを選択したあとは、"Write"を押してmicroSDカードに焼きましょう。

![rpii-write.png](./burn-sd/rpii-write.png)

「本当にmicroSDカード内の情報を削除しても問題ないか？」と聞かれますが、"Yes"を押しましょう。

![rpii-write-confirm.png](./burn-sd/rpii-write-confirm.png)

その後、書き込みと書き込みが正しく行われているかの検証を行い、次の画像のように"Write Successful"の表示が出れば成功です。この画面が出ればmicroSDカードを抜いても問題ありません。

![rpii-finish.png](./burn-sd/rpii-finish.png)

同じ要領で残り2枚も焼いておきましょう。

## Raspberry PiへSSHする

今回は3台のRaspberry PiへSSHし、手元のマシンからアクセスできるようにしましょう。

最初にRaspberry PiをHDMIディスプレイに接続します。"microHDMI-HDMIケーブル"を取りだし、Raspberry Pi本体にケーブルを挿してください。

![microHDMIポート](./ssh/01_microhdmiport.jpg)

合わせてUSBポートにキーボードを刺した上で、スイッチの電源を入れましょう。LANケーブルを刺した時点でRaspberry Piが起動するため、1台ずつ起動するためにLANケーブルを一時的に抜いておくことを推奨します。

起動後はこちらのような画面になります。

![起動時の画面](./ssh/02_boot.png)

初期状態ではユーザ名パスワードともに"ubuntu"になっているのでこれを入力してください。

初回起動時にはパスワードの変更を求められるため、適切なパスワードに変更してください。

![パスワードを変更する](./ssh/03_retype.png)

無事にログインとパスワードの変更ができれば、以下のような表示になります。

![ログイン成功時の画面](./ssh/04_logined.png)

ログインに成功した際の画面から、"IPv4 Address for eth0"に表示されているIPアドレスを確認しておきましょう。

![IPアドレスを確認する](./ssh/05_ip.png)

このIPアドレスに対して、手元のマシンからSSHできることを確認しましょう。

```
$ ssh ubuntu@192.168.53.100
The authenticity of host '192.168.53.100 (192.168.53.100)' can't be established.
ECDSA key fingerprint is SHA256:7OU53DVWFvn2x7rjP8jcNeANG40ZLW2IIBuckq9dtAw.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.53.100' (ECDSA) to the list of known hosts.
ubuntu@192.168.53.100's password:
Welcome to Ubuntu 20.04.1 LTS (GNU/Linux 5.4.0-1015-raspi aarch64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Wed Mar 18 00:00:00 JST 1998

  System load:           1.29
  Usage of /:            7.0% of 28.10GB
  Memory usage:          5%
  Swap usage:            0%
  Temperature:           45.8 C
  Processes:             144
  Users logged in:       1
  IPv4 address for eth0: 192.168.53.100
  IPv6 address for eth0: 240b:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx

 * Kubernetes 1.19 is out! Get it in one command with:

     sudo snap install microk8s --channel=1.19 --classic

   https://microk8s.io/ has docs and details.

60 updates can be installed immediately.
19 of these updates are security updates.
To see these additional updates run: apt list --upgradable


Last login: Wed Mar 18 00:00:00 JST 1998
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@ubuntu:~$
```

無事にSSHできれば動作確認完了です。

他の2台についてもmicroHDMIケーブルとUSBキーボードを刺した上で電源を入れ、SSHできることを確認してください。

今回設定されたIPアドレスはDHCPで設定されているため、変動してしまう可能性があります。IPアドレスを変えたい場合はお好みのIPアドレスに設定してください。
