use starknet::ContractAddress;

#[derive(Serde, Drop, Copy, starknet::Store, Debug)]
pub struct RequestInternal {
    pub project_address_: ContractAddress,
    pub vintage_: u256,
    pub amount_: u256,
    pub filled_: u256,
    pub tx_hash_: u256,
    pub timestamp_: u64,
}

#[derive(Serde, Drop, Copy, starknet::Store, Debug)]
pub struct Request {
    pub project_address: ContractAddress,
    pub vintage: u256,
    pub amount: u256,
    pub filled: u256,
    pub tx_hash: u256,
    pub timestamp: u64,
}

#[starknet::interface]
pub trait IOffsettor<TContractState> {
    // Gets the user requests
    fn get_requests(self: @TContractState, user: ContractAddress) -> Array<Request>;

    // Gets all user requests with remaining amount to be filled
    fn get_pending_requests(self: @TContractState) -> Array<Request>;

    // Adds a project to the list
    fn add_project(ref self: TContractState, project_address: ContractAddress);

    // Adds a request of the user
    fn request_offset(
        ref self: TContractState, project_address: ContractAddress, amount: u256, vintage: u256,
    );

    // Admin function
    // Fulfills the user requests
    fn claim_offset(
        ref self: TContractState, user: ContractAddress, request_number: u32, amount: u256
    );
}

#[starknet::contract]
pub mod Offsettor {
    use OwnableComponent::InternalTrait;
    use starknet::{ContractAddress, ClassHash};
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry,
    };
    use starknet::{get_caller_address, get_contract_address, get_tx_info, get_block_timestamp};
    use crate::interfaces::{IProjectDispatcher, IProjectDispatcherTrait};

    use super::{Request, RequestInternal};

    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        pub requests: Map<(ContractAddress, u32), RequestInternal>,
        pub num_requests: Map<ContractAddress, u32>,
        pub depositors: Map<u32, ContractAddress>,
        pub num_depositors: u32,
        pub projects: Map<ContractAddress, bool>,
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pub upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl OffsettorImpl of super::IOffsettor<ContractState> {
        fn get_pending_requests(self: @ContractState) -> Array<Request> {
            let mut requests = array![];
            for depositor_index in 0
                ..self
                    .num_depositors
                    .read() {
                        let user = self.depositors.entry(depositor_index).read();
                        let num_requests = self.num_requests.entry(user).read();
                        for i in 0
                            ..num_requests {
                                let r = self.requests.entry((user, i)).read();
                                let project = IProjectDispatcher {
                                    contract_address: r.project_address_
                                };
                                let amount = project.internal_to_cc(r.amount_, r.vintage_);
                                let filled = project.internal_to_cc(r.filled_, r.vintage_);
                                if amount - filled > 10_000 {
                                    let request = Request {
                                        project_address: r.project_address_,
                                        vintage: r.vintage_,
                                        amount,
                                        filled,
                                        tx_hash: r.tx_hash_,
                                        timestamp: r.timestamp_,
                                    };
                                    requests.append(request);
                                }
                            };
                    };
            requests
        }

        fn get_requests(self: @ContractState, user: ContractAddress) -> Array<Request> {
            let num_requests = self.num_requests.entry(user).read();
            let mut requests = array![];
            for i in 0
                ..num_requests {
                    let r = self.requests.entry((user, i)).read();
                    let vintage = r.vintage_;

                    // Convert internal to cc
                    let project = IProjectDispatcher { contract_address: r.project_address_ };
                    let amount = project.internal_to_cc(r.amount_, vintage);
                    let filled = project.internal_to_cc(r.filled_, vintage);

                    let request = Request {
                        project_address: r.project_address_,
                        vintage,
                        amount,
                        filled,
                        tx_hash: r.tx_hash_,
                        timestamp: r.timestamp_,
                    };
                    requests.append(request);
                };
            requests
        }

        fn add_project(ref self: ContractState, project_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.projects.entry(project_address).write(true);
        }

        fn request_offset(
            ref self: ContractState, project_address: ContractAddress, amount: u256, vintage: u256,
        ) {
            let caller = get_caller_address();
            let this = get_contract_address();
            let tx_info = get_tx_info().unbox();

            // assert project in list?
            assert!(self.projects.entry(project_address).read(), "Project not found");
            let project = IProjectDispatcher { contract_address: project_address };

            // Transfer vintage
            project.safe_transfer_from(caller, this, vintage, amount, array![].span());

            // Add requests
            let internal_cc = project.cc_to_internal(amount, vintage);
            let r = RequestInternal {
                project_address_: project_address,
                amount_: internal_cc,
                vintage_: vintage,
                filled_: 0,
                tx_hash_: tx_info.transaction_hash.into(),
                timestamp_: get_block_timestamp(),
            };
            let num_requests = self.num_requests.entry(caller).read();
            let new_num_requests = num_requests + 1;
            self.num_requests.entry(caller).write(new_num_requests);

            // Add depositor if first request
            if num_requests == 0 {
                self.depositors.entry(self.num_depositors.read()).write(caller);
                self.num_depositors.write(self.num_depositors.read() + 1);
            }

            self.requests.entry((caller, num_requests)).write(r);
        }

        fn claim_offset(
            ref self: ContractState, user: ContractAddress, request_number: u32, amount: u256
        ) {
            self.ownable.assert_only_owner();
            let this = get_contract_address();
            let r = self.requests.entry((user, request_number)).read();
            let project = IProjectDispatcher { contract_address: r.project_address_ };

            let internal_cc_burned = project.cc_to_internal(amount, r.vintage_);
            let new_filled = r.filled_ + internal_cc_burned;
            let new_amount = r.amount_ - internal_cc_burned;

            // burn amount
            project
                .safe_transfer_from(
                    this, 0xdead.try_into().unwrap(), r.vintage_, amount, array![].span()
                );

            // update request
            let new_request = RequestInternal {
                project_address_: r.project_address_,
                amount_: new_amount,
                vintage_: r.vintage_,
                filled_: new_filled,
                tx_hash_: r.tx_hash_,
                timestamp_: r.timestamp_,
            };
            self.requests.entry((user, request_number)).write(new_request);
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
