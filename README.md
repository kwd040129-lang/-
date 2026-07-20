# Tamagotchi Gemini backend

Love2D 게임의 메시지를 Gemini에 전달하는 Express 서버입니다.

## 로컬 실행

1. `.env`의 `GEMINI_API_KEY`에 로컬 개발용 키를 입력합니다.
2. 의존성을 설치하고 서버를 실행합니다.

```bash
npm install
npm start
```

기본 주소는 `http://localhost:3000`입니다.

## API

`POST /chat`

```json
{
  "message": "안녕! 오늘 뭐 하고 놀까?"
}
```

성공 응답:

```json
{
  "reply": "Gemini가 생성한 답변"
}
```

## Render 배포

저장소를 Render Blueprint로 연결하면 루트의 `render.yaml`을 사용합니다.
초기 생성 화면에서 `GEMINI_API_KEY` 값을 입력하세요. 키를 Git 저장소나
Love2D 코드에 넣으면 안 됩니다.

배포 후 Love2D에서는 다음 형식으로 요청합니다.

```text
POST https://YOUR-SERVICE.onrender.com/chat
Content-Type: application/json

{"message":"유저 메시지"}
```
