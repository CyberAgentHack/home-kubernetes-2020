# weave scope でクラスターを可視化してみよう

## weave scope とは

クラスターの状態をリアルタイムで可視化してくれるツール

- https://www.weave.works/oss/scope/

## install

- arm64 の image が無かったので作成しました
- こちらの [manifest](https://gist.github.com/makocchi-ca/a74fa0c88a276f2b8fd8218c18967a26#file-weave-scope-arm64-1-13-1-yaml) を適用してください
- install 後、`weave` の namespace に `weave-scope-app` という Service が作られますが、これを port-forward するか NodePort に変えることで GUI にアクセスすることができます
