import { CfnParameter, Stack, StackProps } from "aws-cdk-lib";
import { HttpApi, HttpMethod, VpcLink } from "aws-cdk-lib/aws-apigatewayv2";
import { HttpAlbIntegration } from "aws-cdk-lib/aws-apigatewayv2-integrations";
import { Port, SecurityGroup, Vpc, SubnetFilter } from "aws-cdk-lib/aws-ec2";
import { ContainerImage, CpuArchitecture } from "aws-cdk-lib/aws-ecs";
import { ApplicationLoadBalancedFargateService } from "aws-cdk-lib/aws-ecs-patterns";
import { Construct } from "constructs";

export class ReplicatorDemo extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // inputs
    const vpcId = new CfnParameter(this, "VpcId", {
      type: "String",
    });
    const subnetsParameter = new CfnParameter(this, "Subnets", {
      type: "List<AWS::EC2::Subnet::Id>",
    });

    // fabricate the VPC
    const vpc = Vpc.fromVpcAttributes(this, "Vpc", {
      vpcId: vpcId.valueAsString,
      availabilityZones: ["us-east-1a"],
      privateSubnetIds: subnetsParameter.valueAsList,
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

    const vpcLink = new VpcLink(this, "VpcLink", {
      vpc,
      subnets: {
        subnetFilters: [
          SubnetFilter.byIds(subnetsParameter.valueAsList),
        ],
      },
    });

    const apigwIntegration = new HttpAlbIntegration("LbIntegration", backendApp.listener, {
      vpcLink,
      method: HttpMethod.ANY,
    });

    const httpApi = new HttpApi(this, "Api", {});
    httpApi.addRoutes({
      path: "/{proxy+}",
      methods: [HttpMethod.ANY],
      integration: apigwIntegration,
    });
  }
}
