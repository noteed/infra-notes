#! /usr/bin/env nix-shell
#! nix-shell -i bash -p ssh-to-age -p yq-go

echo "Retrieving host key..."

IP_ADDR=$(
  tofu state show \
    "module.infra.module.gh-runner-1.aws_instance.node" \
    | grep "^    public_ip" \
    | cut -d '"' -f 2
)

echo "IP address: ${IP_ADDR}"

AGE_KEY=$(ssh-keyscan -t ed25519 "${IP_ADDR}" 2> /dev/null | ssh-to-age)

echo "AGE key: ${AGE_KEY}"

yq '
  ( .keys |=
    ( filter(anchor != "ghrunner")
      | . + ["'"${AGE_KEY}"'"
      | . anchor = "ghrunner"]
      | sort_by(anchor)
    )
  ) |
  ( .creation_rules[0].key_groups[0].age |=
    ( filter(alias != "ghrunner")
      | . + ["" | . alias = "ghrunner"]
      | sort
    )
  )' --inplace ../../../.sops.yaml


echo "You should retrieve the GitHub private key and run"
echo "nix-shell -p --run 'sops updatekeys ../../../secrets/gh-runner.yaml --yes'"
