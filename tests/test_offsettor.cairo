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
    migrator.migrate(project_address, cc_amount, holder);
    stop_cheat_caller_address(migrator_address);

    start_cheat_caller_address(project_address, holder);
    project.set_approval_for_all(offsettor_address, true);
    stop_cheat_caller_address(project_address);

    start_cheat_caller_address(offsettor_address, owner);
    offsettor.add_project(project_address);
    stop_cheat_caller_address(offsettor_address);

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
    let total_filled = *user_requests[1].filled + *user_requests[0].filled;
    let total_remaining = *user_requests[1].amount + *user_requests[0].amount;
    println!("user_requests: {:?}", user_requests);
    println!("total filled: {:?}", total_filled);
    println!("total remaining: {:?}", total_remaining);
}


#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
fn test_with_rebase() {
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
    migrator.migrate(project_address, cc_amount, holder);
    stop_cheat_caller_address(migrator_address);

    start_cheat_caller_address(project_address, holder);
    project.set_approval_for_all(offsettor_address, true);
    stop_cheat_caller_address(project_address);

    start_cheat_caller_address(offsettor_address, owner);
    offsettor.add_project(project_address);
    stop_cheat_caller_address(offsettor_address);

    start_cheat_caller_address(offsettor_address, holder);
    let balance = project.balance_of(holder, 2);
    let amount = (balance / 1_000_000) * 1_000_000;
    offsettor.request_offset(project_address, amount, 2);
    stop_cheat_caller_address(offsettor_address);

    let user_requests = offsettor.get_requests(holder);
    println!("req.amount {:?}, amount={:?}", *user_requests[0].amount, amount);
    assert!(amount - *user_requests[0].amount < 10);

    start_cheat_caller_address(project_address, owner);
    let old_supply = project.get_carbon_vintage(2).supply;
    project.rebase_vintage(2, old_supply / 2);
    stop_cheat_caller_address(project_address);

    let user_requests = offsettor.get_requests(holder);
    println!("req.amount {:?}, amount={:?}", *user_requests[0].amount, amount / 2);
    assert!(amount / 2 - *user_requests[0].amount < 10);

    start_cheat_caller_address(offsettor_address, owner);
    offsettor.claim_offset(holder, 0, amount / 2);
    stop_cheat_caller_address(offsettor_address);

    let user_requests = offsettor.get_requests(holder);
    println!(
        "req.amount {:?}, req.filled: {:?} amount={:?}",
        *user_requests[0].amount,
        *user_requests[0].filled,
        amount
    );
    assert!(*user_requests[0].amount == 0 && amount / 2 - *user_requests[0].filled < 10);
}


#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
fn test_pending_requests() {
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
    project.set_approval_for_all(offsettor_address, true);
    stop_cheat_caller_address(project_address);

    start_cheat_caller_address(migrator_address, owner);
    migrator.migrate(project_address, cc_amount, holder);
    migrator.migrate(project_address, cc_amount, owner);
    stop_cheat_caller_address(migrator_address);

    let balance = project.balance_of(holder, 2);
    let amount = (balance / 1_000_000) * 1_000_000;

    start_cheat_caller_address(project_address, holder);
    project.set_approval_for_all(offsettor_address, true);
    stop_cheat_caller_address(project_address);

    start_cheat_caller_address(offsettor_address, owner);
    offsettor.add_project(project_address);
    offsettor.request_offset(project_address, amount / 2, 2); // #0
    offsettor.request_offset(project_address, amount / 4, 2); // #1
    offsettor.request_offset(project_address, amount / 8, 2); // #2
    stop_cheat_caller_address(offsettor_address);

    start_cheat_caller_address(offsettor_address, holder);
    offsettor.request_offset(project_address, amount / 2, 2); // #3
    offsettor.request_offset(project_address, amount / 2, 2); // #4
    stop_cheat_caller_address(offsettor_address);

    start_cheat_caller_address(offsettor_address, owner);
    offsettor.request_offset(project_address, amount / 16, 2); // #5
    stop_cheat_caller_address(project_address);

    let pending_requests = offsettor.get_pending_requests(0, 100);
    println!("pending_requests: {:?}", pending_requests);
    assert!(pending_requests.len() == 6);

    start_cheat_caller_address(offsettor_address, owner);
    offsettor.claim_offset(holder, 0, amount / 2);
    offsettor.claim_offset(holder, 1, amount / 4);
    offsettor.claim_offset(holder, 2, amount / 8);
    offsettor.claim_offset(owner, 3, amount / 3);
    stop_cheat_caller_address(offsettor_address);

    let pending_requests = offsettor.get_pending_requests(0, 100);
    println!("pending_requests: {:?}", pending_requests);
    assert!(pending_requests.len() == 3);
}
