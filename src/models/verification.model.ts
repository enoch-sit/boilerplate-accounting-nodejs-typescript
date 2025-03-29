// src/models/verification.model.ts
// Importing necessary dependencies from mongoose for defining the schema and document structure
import mongoose, { Document, Schema } from 'mongoose';

// Enum to define the types of verification that can be performed
export enum VerificationType {
  EMAIL = 'email',
  PASSWORD_RESET = 'password-reset'
}

// Interface defining the structure of a verification document
export interface IVerification extends Document {
  userId: mongoose.Types.ObjectId; // Reference to the user who needs verification
  type: VerificationType; // Type of verification being performed
  token: string; // Unique token used for verification
  expires: Date; // Expiration date of the verification token
  createdAt: Date; // Timestamp when the verification was created
  updatedAt: Date; // Timestamp when the verification was last updated
}

// Schema definition for the Verification model
const VerificationSchema = new Schema<IVerification>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User', // Reference to the User model
      required: true // This field is mandatory
    },
    type: {
      type: String,
      enum: Object.values(VerificationType), // Ensures the type is one of the defined VerificationType values
      required: true // This field is mandatory
    },
    token: {
      type: String,
      required: true // This field is mandatory
    },
    expires: {
      type: Date,
      required: true // This field is mandatory
    }
  },
  {
    timestamps: true // Automatically adds createdAt and updatedAt fields
  }
);

// Index to automatically remove expired verifications
// This index ensures that documents are automatically deleted when they expire
VerificationSchema.index({ expires: 1 }, { expireAfterSeconds: 0 });

// Exporting the Verification model for use in other parts of the application
export const Verification = mongoose.model<IVerification>('Verification', VerificationSchema);
