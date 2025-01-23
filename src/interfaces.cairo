use starknet::ContractAddress;

#[starknet::interface]
pub trait IProject<TContractState> {
    fn get_num_vintages(self: @TContractState) -> usize;
    fn batch_mint(
        ref self: TContractState, to: ContractAddress, token_ids: Span<u256>, values: Span<u256>
    );
    fn balance_of(self: @TContractState, owner: ContractAddress, token_id: u256) -> u256;
    fn balance_of_batch(
        self: @TContractState, owners: Span<ContractAddress>, token_ids: Span<u256>
    ) -> Span<u256>;
    fn grant_minter_role(self: @TContractState, minter: ContractAddress);
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    );
    fn cc_to_internal(self: @TContractState, cc_value_to_send: u256, token_id: u256) -> u256;
    fn internal_to_cc(self: @TContractState, internal_value_to_send: u256, token_id: u256) -> u256;
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approve: bool);
}
