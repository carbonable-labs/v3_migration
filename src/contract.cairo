use starknet::ContractAddress;

pub const MULTIPLIER_TONS_TO_MGRAMS: u256 = 1_000_000_000;

#[starknet::interface]
pub trait IMigration<TContractState> {
    fn migrate_v2(
        ref self: TContractState,
        project_address: ContractAddress,
        amount: u256,
        holder: ContractAddress
    );
}

#[starknet::contract]
pub mod MigrationV3 {
    use OwnableComponent::InternalTrait;
    use starknet::{ContractAddress};
    use crate::interfaces::{IProjectDispatcher, IProjectDispatcherTrait};

    use openzeppelin_access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl MigationImpl of super::IMigration<ContractState> {
        fn migrate_v2(
            ref self: ContractState,
            project_address: ContractAddress,
            amount: u256,
            holder: ContractAddress
        ) {
            self.ownable.assert_only_owner();
            let project = IProjectDispatcher { contract_address: project_address };
            let num_vintages: usize = project.get_num_vintages();

            let mut tokens_ids: Array<u256> = Default::default();
            let mut values_cc: Array<u256> = Default::default();
            let mut index = 0;
            loop {
                if index >= num_vintages {
                    break;
                }
                values_cc.append(amount.into());
                let token_id = (index + 1).into();
                tokens_ids.append(token_id);
                index += 1;
            };

            // [Interaction] Mint
            project.batch_mint(holder, tokens_ids.span(), values_cc.span());
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {}
}
