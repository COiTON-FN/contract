set_env:
	export STARKNET_ACCOUNT=~/.starkli-wallets/deployer/my_account_1.json \
    export STARKNET_KEYSTORE=~/.starkli-wallets/deployer/my_keystore_1.json \
    export STARKNET_RPC=https://starknet-sepolia.public.blastapi.io/rpc/v0_7


declare:
	sncast \
    declare \
    --fee-token eth \
    --contract-name ${name}

deploy:
	sncast deploy --fee-token eth --class-hash ${classhash} --constructor-calldata ${arg}


t:
	export SNFORGE_BACKTRACE=1 && snforge test

upgrade:
	sncast \
	invoke \
	--fee-token eth \
	--contract-address ${address} \
	--function "upgrade" \
	--calldata ${calldata}