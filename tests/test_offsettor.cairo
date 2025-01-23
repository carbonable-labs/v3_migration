use starknet::{ContractAddress, contract_address_const};

use snforge_std::{
    declare, DeclareResultTrait, ContractClassTrait, start_cheat_caller_address,
    stop_cheat_caller_address
};

use v3_migration::migrator::{IMigrationDispatcher, IMigrationDispatcherTrait};
use v3_migration::offsettor::{IOffsettorDispatcher, IOffsettorDispatcherTrait};
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

#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
fn test_offset() {
    let owner = contract_address_const::<OWNER_ADDRESS_FELT>();
    let holder = contract_address_const::<'HOLDER'>();
    let migrator_address = deploy_contract("MigrationV3", array![owner.into()]);
    let offsettor_address = deploy_contract("Offsettor", array![owner.into()]);
    let project_address = contract_address_const::<PROJECT_ADDRESS_FELT>();

    let project = IProjectDispatcher { contract_address: project_address };
    let migrator = IMigrationDispatcher { contract_address: migrator_address };
    let offsettor = IOffsettorDispatcher { contract_address: offsettor_address };

    let cc_amount: u256 = 100_000_000_000;

    start_cheat_caller_address(project_address, owner);
    project.grant_minter_role(migrator_address);
    stop_cheat_caller_address(project_address);

    start_cheat_caller_address(migrator_address, owner);
    migrator.migrate_v2(project_address, cc_amount, holder);
    stop_cheat_caller_address(migrator_address);

    start_cheat_caller_address(project_address, holder);
    project.set_approval_for_all(offsettor_address, true);
    stop_cheat_caller_address(project_address);

    start_cheat_caller_address(offsettor_address, holder);
    let balance = project.balance_of(holder, 2);
    offsettor.request_offset(project_address, balance / 2, 2);
    offsettor.request_offset(project_address, balance / 2, 2);
    stop_cheat_caller_address(offsettor_address);

    let user_requests = offsettor.get_requests(holder);
    println!("user_requests: {:?}", user_requests);
    println!("balance: {:?}, internal: {:?}", balance, project.cc_to_internal(balance, 2));

    start_cheat_caller_address(offsettor_address, owner);
    offsettor.claim_offset(holder, 0, balance / 2);
    offsettor.claim_offset(holder, 1, balance / 4);
    offsettor.claim_offset(holder, 1, balance / 8);
    offsettor.claim_offset(holder, 1, balance / 8);
    stop_cheat_caller_address(offsettor_address);

    let user_requests = offsettor.get_requests(holder);
    println!("user_requests: {:?}", user_requests);
    println!("1filled: {:?}", project.internal_to_cc(*user_requests[1].amount_filled, 2));
    println!("1remaining: {:?}", project.internal_to_cc(*user_requests[1].amount, 2));
    println!("0filled: {:?}", project.internal_to_cc(*user_requests[0].amount_filled, 2));
    println!("remaining: {:?}", project.internal_to_cc(*user_requests[0].amount, 2));
}
