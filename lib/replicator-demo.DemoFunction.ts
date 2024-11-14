import { APIGatewayProxyHandler } from "aws-lambda";

export const handler: APIGatewayProxyHandler = async (event, context) => {
  console.log({ event, context });
  console.log(`Load Balancer domain: ${process.env.BACKEND_URL}`);

  const url = `http://${process.env.BACKEND_URL}`;
  const res = await fetch(url);
  if (!res.ok) {
    const responseBody = await res.text();
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Error making request to backend",
        originalCode: res.status,
        originalBody: responseBody,
      }),
    };
  }

  const payload = await res.json();

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "hello world",
      payload,
    }),
  };
};
