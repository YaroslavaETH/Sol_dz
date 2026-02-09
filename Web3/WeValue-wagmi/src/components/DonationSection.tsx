import { DonationForm } from '../write-contract.tsx';

export function DonationSection() {
  return (
    <div className="mt-4">
      <h3 className="mb-3">Помочь фонду</h3>
      <DonationForm />
    </div>
  );
}
