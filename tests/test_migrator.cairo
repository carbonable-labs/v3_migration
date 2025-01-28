use starknet::{ContractAddress, contract_address_const};

use snforge_std::{
    declare, DeclareResultTrait, ContractClassTrait, start_cheat_caller_address,
    stop_cheat_caller_address
};

use v3_migration::migrator::{IMigrationDispatcher, IMigrationDispatcherTrait};
use v3_migration::interfaces::{IProjectDispatcher, IProjectDispatcherTrait};

const PROJECT_ADDRESS_FELT: felt252 =
    0x0055ff4fa579b03f0bd6bda46c96c4739d2b6962db67d9acd87d5b765ff3da65;
const OWNER_ADDRESS_FELT: felt252 =
    0x01e2f67d8132831f210e19c5ee0197aa134308e16f7f284bba2c72e28fc464d2;

fn deploy_contract(name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

fn helper_batch_balance_args(
    holder: ContractAddress, num_vintages: usize
) -> (Span<ContractAddress>, Span<u256>) {
    let mut owners: Array<ContractAddress> = array![];
    let mut token_ids: Array<u256> = array![];
    let mut token_id: u256 = 1;
    loop {
        if token_id > num_vintages.into() {
            break;
        }
        owners.append(holder);
        token_ids.append(token_id);
        token_id += 1;
    };
    (owners.span(), token_ids.span())
}

fn sum(values: Span<u256>) -> u256 {
    let mut sum: u256 = 0;
    for value in values {
        sum += *value;
    };
    sum
}

#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
fn test_migrate() {
    let owner = contract_address_const::<OWNER_ADDRESS_FELT>();
    let holder = contract_address_const::<'HOLDER'>();
    let contract_address = deploy_contract("MigrationV3", array![owner.into()]);
    let project_address = contract_address_const::<PROJECT_ADDRESS_FELT>();
    let project = IProjectDispatcher { contract_address: project_address };
    let migrator = IMigrationDispatcher { contract_address };
    let cc_amount: u256 = 100_000_000_000;

    start_cheat_caller_address(project_address, owner);
    project.grant_minter_role(contract_address);
    stop_cheat_caller_address(project_address);

    start_cheat_caller_address(contract_address, owner);
    migrator.migrate(project_address, cc_amount, holder);
    stop_cheat_caller_address(contract_address);

    // start_cheat_caller_address(project_address, holder);

    let num_vintages: usize = project.get_num_vintages();

    let (owners, token_ids) = helper_batch_balance_args(holder, num_vintages);

    let balances = project.balance_of_batch(owners, token_ids);
    let sum_balance = sum(balances);

    println!("sum_balance: {:?}", sum_balance);
    assert!(sum_balance + 10 >= cc_amount, "wrong balance");
}


#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
fn test_migrate_twenty() {
    let owner = contract_address_const::<OWNER_ADDRESS_FELT>();
    let holder = contract_address_const::<'HOLDER'>();
    let contract_address = deploy_contract("MigrationV3", array![owner.into()]);
    let project_address = contract_address_const::<PROJECT_ADDRESS_FELT>();
    let project = IProjectDispatcher { contract_address: project_address };
    let migrator = IMigrationDispatcher { contract_address };
    let cc_amount: u256 = 100_000_000_000;

    start_cheat_caller_address(project_address, owner);
    project.grant_minter_role(contract_address);
    stop_cheat_caller_address(project_address);

    start_cheat_caller_address(contract_address, owner);
    for _ in 0..20_u8 {
        migrator.migrate(project_address, cc_amount, holder);
    };
    stop_cheat_caller_address(contract_address);
}

#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
fn test_migrate_twenty_batch() {
    let owner = contract_address_const::<OWNER_ADDRESS_FELT>();
    let holder = contract_address_const::<'HOLDER'>();
    let contract_address = deploy_contract("MigrationV3", array![owner.into()]);
    let project_address = contract_address_const::<PROJECT_ADDRESS_FELT>();
    let project = IProjectDispatcher { contract_address: project_address };
    let migrator = IMigrationDispatcher { contract_address };
    let cc_amount: u256 = 100_000_000_000;

    start_cheat_caller_address(project_address, owner);
    project.grant_minter_role(contract_address);
    stop_cheat_caller_address(project_address);

    start_cheat_caller_address(contract_address, owner);

    migrator
        .migrate_batch(
            project_address,
            array![
                cc_amount + 0,
                cc_amount + 1,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount,
                cc_amount
            ]
                .span(),
            array![
                holder,
                holder,
                owner,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder,
                holder
            ]
                .span()
        );

    stop_cheat_caller_address(contract_address);
}
