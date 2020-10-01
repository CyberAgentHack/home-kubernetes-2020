# weave scope でクラスターを可視化してみよう

## weave scope とは

クラスターの状態をリアルタイムで可視化してくれるツール

- https://www.weave.works/oss/scope/

## install

- arm64 の image が無かったので作成しました
- install 後、`weave` の namespace に `weave-scope-app` という Service が作られますが、これを port-forward するか NodePort に変えることで GUI にアクセスすることができます
- manifest は[こちら](weave-scope-arm64-1.13.1.yaml)です
- download もしくは直接 url を指定して apply してください

```bash
$ kubectl apply -f weave-scope-arm64-1.13.1.yaml
```