export const idlFactory = ({ IDL }) => {
  const Sell = IDL.Service({});
  return Sell;
};
export const init = ({ IDL }) => { return [IDL.Principal]; };
