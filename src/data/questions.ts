export interface Question {
  id?: number;
  question: string;
  options: string[];
  correctIndex?: number; // Removed from client logic, optional
  points?: number;
  image?: string;
}

// All questions, answers, and hints have been securely migrated to the database.
