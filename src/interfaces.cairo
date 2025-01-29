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
    fn rebase_vintage(ref self: TContractState, token_id: u256, new_cc_supply: u256);
    fn get_carbon_vintage(self: @TContractState, token_id: u256) -> CarbonVintage;
}

#[derive(Copy, Drop, Debug, starknet::Store, Serde, PartialEq, Default)]
pub struct CarbonVintage {
    /// The year of the vintage
    pub year: u32,
    /// The total supply of Carbon Credit for this vintage.
    pub supply: u256,
    /// The total amount of Carbon Credit that was failed during audits.
    pub failed: u256,
    /// The total amount of Carbon Credit that was created during audits.
    pub created: u256,
    /// The status of the Carbon Credit of this Vintage.
    pub status: CarbonVintageType,
}

#[derive(Copy, Drop, Debug, starknet::Store, Serde, PartialEq, Default)]
pub enum CarbonVintageType {
    #[default]
    /// Unset: the Carbon Credit is not yet created nor projected.
    Unset,
    ///  Projected: the Carbon Credit is not yet created and was projected during certification of
    ///  the project.
    Projected,
    ///  Confirmed: the Carbon Credit is confirmed by a dMRV analyse.
    Confirmed,
    ///  Audited: the Carbon Credit is audited by a third Auditor.
    Audited,
}
