{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SqsWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "events.amazonaws.com",
          "sqs.amazonaws.com"
        ]
      },
      "Action": "sqs:SendMessage",
      "Resource": "${karpenter_sqs_arn}"
    },
    {
      "Sid": "DenyHTTP",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "sqs:*",
      "Resource": "${karpenter_sqs_arn}",
      "Condition": {
        "StringEquals": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
