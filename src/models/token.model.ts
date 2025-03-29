// src/models/token.model.ts
// Importing necessary modules from mongoose for schema definition and document handling
import mongoose, { Document, Schema } from 'mongoose';

// Defining the interface for the Token model which extends the Document type
export interface IToken extends Document {
  userId: mongoose.Types.ObjectId; // Reference to the user's ID
  refreshToken: string; // The refresh token string
  expires: Date; // Expiration date of the token
  createdAt: Date; // Timestamp for when the token was created
  updatedAt: Date; // Timestamp for when the token was last updated
}

// Defining the schema for the Token model
const TokenSchema = new Schema<IToken>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User', // Reference to the User model
      required: true // This field is mandatory
    },
    refreshToken: {
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

// Creating an index on the 'expires' field to automatically remove expired tokens
TokenSchema.index({ expires: 1 }, { expireAfterSeconds: 0 });

// Exporting the Token model created from the TokenSchema
export const Token = mongoose.model<IToken>('Token', TokenSchema);
