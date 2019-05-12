resource "random_pet" "stack_name" {}

resource "aws_iam_instance_profile" "this" {
  name = "${random_pet.stack_name.id}"
  role = "${aws_iam_role.this.name}"
}

resource "aws_iam_role" "this" {
  name               = "role_${random_pet.stack_name.id}"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "this" {
  name   = "${random_pet.stack_name.id}"
  path   = "/"
  policy = "${data.aws_iam_policy_document.this.json}"
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = "${aws_iam_role.this.name}"
  policy_arn = "${aws_iam_policy.this.arn}"
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = ["ssm:*"]

    resources = [
      "arn:aws:ssm:*:*:parameter/inventory-app/*",
    ]
  }
}
