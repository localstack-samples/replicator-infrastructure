import { Stack, StackProps } from "aws-cdk-lib";
import { LambdaRestApi } from "aws-cdk-lib/aws-apigateway";
import {
  Port,
  SecurityGroup,
  Vpc,
} from "aws-cdk-lib/aws-ec2";
import {
  ContainerImage,
  CpuArchitecture,
} from "aws-cdk-lib/aws-ecs";
import { ApplicationLoadBalancedFargateService } from "aws-cdk-lib/aws-ecs-patterns";
import { Architecture } from "aws-cdk-lib/aws-lambda";
import { NodejsFunction } from "aws-cdk-lib/aws-lambda-nodejs";
import { Construct } from "constructs";

export class ReplicatorDemo extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const vpcId: string | undefined = this.node.tryGetContext("replicator-vpcid");
    const vpc = Vpc.fromLookup(this, "VPC", {
      vpcId,
    });

    const lambdaSg = new SecurityGroup(this, "LambdaAccess", {
      vpc,
      allowAllOutbound: true,
    });

    const backendPort = 3000;
    const backendApp = new ApplicationLoadBalancedFargateService(
      this,
      "BackendService",
      {
        vpc,
        assignPublicIp: false,
        cpu: 512,
        memoryLimitMiB: 2048,
        desiredCount: 1,
        taskImageOptions: {
          image: ContainerImage.fromAsset("./image"),
          containerPort: backendPort,
          environment: {
            BACKEND_PORT: backendPort.toString(),
          },
        },
        runtimePlatform: {
          cpuArchitecture:
            process.arch === "arm64"
              ? CpuArchitecture.ARM64
              : CpuArchitecture.X86_64,
        },
        publicLoadBalancer: false,
      },
    );
    const lbSg = backendApp.loadBalancer.connections.securityGroups[0];
    lbSg.addIngressRule(
      lambdaSg,
      Port.tcp(443),
      "Allow public HTTPS API access to backend service",
    );
    lbSg.addIngressRule(
      lambdaSg,
      Port.tcp(80),
      "Allow public HTTP API access to backend service",
    );

    const lambda = new NodejsFunction(this, "DemoFunction", {
      architecture:
        process.arch === "arm64" ? Architecture.ARM_64 : Architecture.X86_64,
      vpc,
      environment: {
        BACKEND_URL: backendApp.loadBalancer.loadBalancerDnsName,
      },
      securityGroups: [lambdaSg],
    });

    // allow access from the Lambda function to the load balancer

    new LambdaRestApi(this, "ApiGateway", {
      handler: lambda,
      proxy: true,
    });
  }
}
