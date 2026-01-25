// Copy this file to: YourApp/Frontend/src/components/UserCostDisplay.tsx

import React, { useEffect, useState } from 'react';
import axios from 'axios'; // Or your configured axios instance

// ============================================
// TypeScript Types
// ============================================

interface UserCostSummary {
  userId: string;
  totalCost: number;
  totalTokens: number;
  totalRequests: number;
  firstRequest: string;
  lastRequest: string;
  costByProvider: Record<string, number>;
  costByModel: Record<string, number>;
}

// ============================================
// Component Props
// ============================================

interface UserCostDisplayProps {
  userId?: string; // Optional: for admin viewing other users
  showDetails?: boolean; // Show provider/model breakdown
  className?: string; // Custom styling
}

// ============================================
// Main Component
// ============================================

export const UserCostDisplay: React.FC<UserCostDisplayProps> = ({
  userId,
  showDetails = false,
  className = ''
}) => {
  const [summary, setSummary] = useState<UserCostSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadCostSummary();
  }, [userId]);

  const loadCostSummary = async () => {
    setLoading(true);
    setError(null);
    try {
      // Adjust API URL to match your backend
      const endpoint = userId
        ? `/api/user-costs/${userId}/summary`
        : '/api/user-costs/my-summary';

      const response = await axios.get(endpoint);
      setSummary(response.data);
    } catch (err: any) {
      setError(err.response?.data?.message || err.message || 'Failed to load cost data');
      console.error('Error loading user costs:', err);
    } finally {
      setLoading(false);
    }
  };

  // ============================================
  // Render States
  // ============================================

  if (loading) {
    return (
      <div className={`bg-white shadow rounded-lg p-6 ${className}`}>
        <div className="animate-pulse">
          <div className="h-4 bg-gray-200 rounded w-1/4 mb-4"></div>
          <div className="h-12 bg-gray-200 rounded w-1/2 mb-4"></div>
          <div className="h-4 bg-gray-200 rounded w-3/4"></div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className={`bg-red-50 border border-red-200 rounded-lg p-6 ${className}`}>
        <div className="text-red-800 font-semibold mb-2">Error Loading Cost Data</div>
        <div className="text-red-600 text-sm">{error}</div>
        <button
          onClick={loadCostSummary}
          className="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
        >
          Retry
        </button>
      </div>
    );
  }

  if (!summary) {
    return (
      <div className={`bg-gray-50 border border-gray-200 rounded-lg p-6 ${className}`}>
        <div className="text-gray-500 text-center">No cost data available</div>
      </div>
    );
  }

  // ============================================
  // Main Render
  // ============================================

  return (
    <div className={`bg-white shadow rounded-lg p-6 ${className}`}>
      {/* Header */}
      <h3 className="text-lg font-semibold text-gray-800 mb-4">
        AI Usage Cost
      </h3>

      {/* Total Cost - Big Number */}
      <div className="mb-6">
        <div className="text-4xl font-bold text-blue-600">
          ${summary.totalCost.toFixed(4)}
        </div>
        <div className="text-sm text-gray-500 mt-1">
          Total lifetime cost
        </div>
      </div>

      {/* Key Metrics Grid */}
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div className="bg-gray-50 rounded-lg p-4">
          <div className="text-2xl font-semibold text-gray-800">
            {summary.totalTokens.toLocaleString()}
          </div>
          <div className="text-xs text-gray-500 mt-1">Total tokens used</div>
        </div>
        <div className="bg-gray-50 rounded-lg p-4">
          <div className="text-2xl font-semibold text-gray-800">
            {summary.totalRequests.toLocaleString()}
          </div>
          <div className="text-xs text-gray-500 mt-1">API requests</div>
        </div>
      </div>

      {/* Average Cost Per Request */}
      <div className="mb-6 p-4 bg-blue-50 rounded-lg">
        <div className="text-sm text-gray-600">Average cost per request</div>
        <div className="text-xl font-semibold text-blue-700">
          ${(summary.totalCost / summary.totalRequests || 0).toFixed(4)}
        </div>
      </div>

      {/* Details Section (Optional) */}
      {showDetails && (
        <>
          {/* Cost by Provider */}
          {Object.keys(summary.costByProvider).length > 0 && (
            <div className="mb-4">
              <h4 className="text-sm font-semibold text-gray-700 mb-2">
                Cost by Provider
              </h4>
              <div className="space-y-2">
                {Object.entries(summary.costByProvider)
                  .sort(([, a], [, b]) => b - a)
                  .map(([provider, cost]) => (
                    <div key={provider} className="flex justify-between items-center">
                      <span className="text-sm text-gray-600 flex items-center">
                        <span className="w-2 h-2 rounded-full bg-blue-500 mr-2"></span>
                        {provider}
                      </span>
                      <span className="text-sm font-medium text-gray-800">
                        ${cost.toFixed(4)}
                      </span>
                    </div>
                  ))}
              </div>
            </div>
          )}

          {/* Cost by Model */}
          {Object.keys(summary.costByModel).length > 0 && (
            <div className="mb-4">
              <h4 className="text-sm font-semibold text-gray-700 mb-2">
                Top Models by Cost
              </h4>
              <div className="space-y-2">
                {Object.entries(summary.costByModel)
                  .sort(([, a], [, b]) => b - a)
                  .slice(0, 5) // Top 5 models
                  .map(([model, cost]) => (
                    <div key={model} className="flex justify-between items-center">
                      <span className="text-sm text-gray-600 truncate max-w-[200px]">
                        {model}
                      </span>
                      <span className="text-sm font-medium text-gray-800">
                        ${cost.toFixed(4)}
                      </span>
                    </div>
                  ))}
              </div>
            </div>
          )}
        </>
      )}

      {/* Footer - Last Updated */}
      <div className="mt-6 pt-4 border-t border-gray-200">
        <div className="text-xs text-gray-400 flex justify-between">
          <span>
            First request: {new Date(summary.firstRequest).toLocaleDateString()}
          </span>
          <span>
            Last request: {new Date(summary.lastRequest).toLocaleString()}
          </span>
        </div>
      </div>

      {/* Refresh Button */}
      <button
        onClick={loadCostSummary}
        className="mt-4 w-full py-2 px-4 border border-gray-300 rounded-md text-sm text-gray-700 hover:bg-gray-50 transition-colors"
      >
        🔄 Refresh Data
      </button>
    </div>
  );
};

// ============================================
// Simplified Inline Display (Alternative)
// ============================================

export const SimpleUserCost: React.FC = () => {
  const [totalCost, setTotalCost] = useState<number | null>(null);

  useEffect(() => {
    axios.get('/api/user-costs/my-summary')
      .then(res => setTotalCost(res.data.totalCost))
      .catch(err => console.error('Failed to load cost:', err));
  }, []);

  if (totalCost === null) return null;

  return (
    <div className="inline-flex items-center bg-gray-100 px-3 py-1 rounded-md">
      <span className="text-xs text-gray-600 mr-2">AI Cost:</span>
      <span className="text-sm font-semibold text-gray-800">
        ${totalCost.toFixed(4)}
      </span>
    </div>
  );
};
