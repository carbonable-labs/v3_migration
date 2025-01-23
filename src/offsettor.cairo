use starknet::ContractAddress;

#[derive(Serde, Drop, Copy, starknet::Store, Debug)]
pub struct Request {
    pub project_address: ContractAddress,
    pub amount: u256,
    pub vintage: u256,
    pub amount_filled: u256,
}

#[starknet::interface]
pub trait IOffsettor<TContractState> {
    // Gets the user requests
    fn get_requests(self: @TContractState, user: ContractAddress) -> Array<Request>;

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
    use starknet::{get_caller_address, get_contract_address};
    use crate::interfaces::{IProjectDispatcher, IProjectDispatcherTrait};

    use super::Request;

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
        pub requests: Map<(ContractAddress, u32), Request>,
        pub num_requests: Map<ContractAddress, u32>,
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
        fn get_requests(self: @ContractState, user: ContractAddress) -> Array<Request> {
            let num_requests = self.num_requests.entry(user).read();
            let mut requests = array![];
            for i in 0
                ..num_requests {
                    let request = self.requests.entry((user, i)).read();
                    requests.append(request);
                };
            requests
        }

        fn request_offset(
            ref self: ContractState, project_address: ContractAddress, amount: u256, vintage: u256,
        ) {
            let caller = get_caller_address();
            let this = get_contract_address();

            // assert project in list?
            let project = IProjectDispatcher { contract_address: project_address };

            // Transfer vintage
            project.safe_transfer_from(caller, this, vintage, amount, array![].span());

            // Add requests
            let internal_cc = project.cc_to_internal(amount, vintage);
            let request = Request {
                project_address, amount: internal_cc, vintage, amount_filled: 0,
            };
            let num_requests = self.num_requests.entry(caller).read();
            let new_num_requests = num_requests + 1;
            self.num_requests.entry(caller).write(new_num_requests);

            self.requests.entry((caller, num_requests)).write(request);
        }

        fn claim_offset(
            ref self: ContractState, user: ContractAddress, request_number: u32, amount: u256
        ) {
            self.ownable.assert_only_owner();
            let this = get_contract_address();
            let request = self.requests.entry((user, request_number)).read();
            let project = IProjectDispatcher { contract_address: request.project_address };

            let internal_cc_burned = project.cc_to_internal(amount, request.vintage);
            let new_amount_filled = request.amount_filled + internal_cc_burned;
            let new_amount = request.amount - internal_cc_burned;

            // burn amount
            project
                .safe_transfer_from(
                    this, 0xdead.try_into().unwrap(), request.vintage, amount, array![].span()
                );

            // update request
            let request = self.requests.entry((user, request_number)).read();
            let new_request = Request {
                project_address: request.project_address,
                amount: new_amount,
                vintage: request.vintage,
                amount_filled: new_amount_filled
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
