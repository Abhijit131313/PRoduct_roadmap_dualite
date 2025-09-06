import React, { useState } from 'react';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';

interface CreateReleaseFormProps {
  onSubmit: (data: {
    name: string;
    description: string;
    targetDate: string;
  }) => void;
  onCancel: () => void;
}

export const CreateReleaseForm: React.FC<CreateReleaseFormProps> = ({
  onSubmit,
  onCancel,
}) => {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [targetDate, setTargetDate] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !targetDate) return;

    setLoading(true);
    try {
      await onSubmit({
        name: name.trim(),
        description: description.trim(),
        targetDate,
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <Input
        label="Release Name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="e.g., Q3 Launch, Version 2.1"
        required
      />

      <div className="space-y-1">
        <label className="block text-sm font-medium text-gray-700">
          Description (Optional)
        </label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="What are the main goals of this release?"
          rows={3}
          className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
        />
      </div>

      <Input
        label="Target Date"
        type="date"
        value={targetDate}
        onChange={(e) => setTargetDate(e.target.value)}
        required
      />

      <div className="flex justify-end space-x-3 pt-4">
        <Button
          type="button"
          variant="outline"
          onClick={onCancel}
          disabled={loading}
        >
          Cancel
        </Button>
        <Button
          type="submit"
          loading={loading}
          disabled={!name.trim() || !targetDate}
        >
          Create Release
        </Button>
      </div>
    </form>
  );
};
